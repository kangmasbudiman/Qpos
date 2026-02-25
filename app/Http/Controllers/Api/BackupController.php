<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BackupController extends Controller
{
    public function download(Request $request)
    {
        $user = $request->user();

        if (!in_array($user->role, ['owner', 'manager', 'super_admin'])) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized. Only owner or manager can perform backup.',
            ], 403);
        }

        $dbName = config('database.connections.mysql.database');
        $dbUser = config('database.connections.mysql.username');
        $dbPass = config('database.connections.mysql.password');
        $dbHost = config('database.connections.mysql.host');
        $dbPort = config('database.connections.mysql.port');

        $timestamp  = now()->format('Y-m-d_H-i-s');
        $gzFilename = 'backup_' . $timestamp . '.sql.gz';

        // Cari path mysqldump (berbeda di tiap server)
        $mysqldumpPath = $this->findMysqldump();

        if ($mysqldumpPath) {
            // Gunakan mysqldump jika tersedia
            return $this->backupViaMysqldump(
                $mysqldumpPath, $dbName, $dbUser, $dbPass, $dbHost, $dbPort,
                $timestamp, $gzFilename
            );
        }

        // Fallback: generate SQL via PDO (tanpa butuh mysqldump)
        return $this->backupViaPdo($dbName, $gzFilename);
    }

    private function findMysqldump(): ?string
    {
        $paths = [
            'mysqldump',                        // PATH default
            '/usr/bin/mysqldump',
            '/usr/local/bin/mysqldump',
            '/usr/mysql/bin/mysqldump',
            '/usr/local/mysql/bin/mysqldump',
            '/opt/lampp/bin/mysqldump',
            '/opt/homebrew/bin/mysqldump',
        ];

        foreach ($paths as $path) {
            exec($path . ' --version 2>/dev/null', $out, $rc);
            if ($rc === 0) return $path;
        }
        return null;
    }

    private function backupViaMysqldump(
        string $bin, string $dbName, string $dbUser, string $dbPass,
        string $dbHost, string $dbPort, string $timestamp, string $gzFilename
    ) {
        $tmpPath = storage_path('app/private/backup_' . $timestamp . '.sql');

        if (!is_dir(storage_path('app/private'))) {
            mkdir(storage_path('app/private'), 0755, true);
        }

        // Tulis password ke .cnf agar aman
        $cnfPath = storage_path('app/private/.my_' . $timestamp . '.cnf');
        file_put_contents($cnfPath, "[mysqldump]\npassword=" . $dbPass . "\n");
        chmod($cnfPath, 0600);

        $command = sprintf(
            '%s --defaults-extra-file=%s --host=%s --port=%s --user=%s --no-tablespaces --skip-comments --single-transaction %s > %s 2>&1',
            $bin,
            escapeshellarg($cnfPath),
            escapeshellarg($dbHost),
            escapeshellarg($dbPort),
            escapeshellarg($dbUser),
            escapeshellarg($dbName),
            escapeshellarg($tmpPath)
        );

        exec($command, $output, $returnCode);
        @unlink($cnfPath);

        if ($returnCode !== 0 || !file_exists($tmpPath) || filesize($tmpPath) === 0) {
            @unlink($tmpPath);
            return response()->json([
                'success' => false,
                'message' => 'Backup failed (code ' . $returnCode . '): ' . implode(' ', $output),
            ], 500);
        }

        return response()->streamDownload(function () use ($tmpPath) {
            $gz = gzopen('php://output', 'wb9');
            $fp = fopen($tmpPath, 'rb');
            while (!feof($fp)) {
                gzwrite($gz, fread($fp, 65536));
            }
            fclose($fp);
            gzclose($gz);
            @unlink($tmpPath);
        }, $gzFilename, [
            'Content-Type'        => 'application/gzip',
            'Content-Disposition' => 'attachment; filename="' . $gzFilename . '"',
            'X-Backup-Method'     => 'mysqldump',
        ]);
    }

    private function backupViaPdo(string $dbName, string $gzFilename)
    {
        // Generate SQL dump via PDO — tidak butuh mysqldump binary
        $pdo = DB::connection()->getPdo();

        $sql  = "-- POS Backup via PDO\n";
        $sql .= "-- Database: {$dbName}\n";
        $sql .= "-- Generated: " . now()->toDateTimeString() . "\n\n";
        $sql .= "SET NAMES utf8mb4;\n";
        $sql .= "SET FOREIGN_KEY_CHECKS = 0;\n\n";

        // Ambil semua tabel
        $tables = $pdo->query("SHOW TABLES")->fetchAll(\PDO::FETCH_COLUMN);

        foreach ($tables as $table) {
            // DROP + CREATE TABLE
            $createRow = $pdo->query("SHOW CREATE TABLE `{$table}`")->fetch(\PDO::FETCH_ASSOC);
            $createSql = array_values($createRow)[1];

            $sql .= "DROP TABLE IF EXISTS `{$table}`;\n";
            $sql .= $createSql . ";\n\n";

            // INSERT data
            $rows = $pdo->query("SELECT * FROM `{$table}`")->fetchAll(\PDO::FETCH_ASSOC);
            if (count($rows) > 0) {
                $cols = '`' . implode('`, `', array_keys($rows[0])) . '`';
                $sql .= "INSERT INTO `{$table}` ({$cols}) VALUES\n";
                $values = [];
                foreach ($rows as $row) {
                    $escaped = array_map(function ($v) use ($pdo) {
                        return $v === null ? 'NULL' : $pdo->quote((string)$v);
                    }, $row);
                    $values[] = '(' . implode(', ', $escaped) . ')';
                }
                $sql .= implode(",\n", $values) . ";\n\n";
            }
        }

        $sql .= "SET FOREIGN_KEY_CHECKS = 1;\n";

        return response()->streamDownload(function () use ($sql) {
            $gz = gzopen('php://output', 'wb9');
            gzwrite($gz, $sql);
            gzclose($gz);
        }, $gzFilename, [
            'Content-Type'        => 'application/gzip',
            'Content-Disposition' => 'attachment; filename="' . $gzFilename . '"',
            'X-Backup-Method'     => 'pdo',
        ]);
    }
}
