<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class BackupController extends Controller
{
    public function download(Request $request)
    {
        $user = $request->user();

        // Hanya owner dan manager yang boleh backup
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
        $filename   = 'backup_' . $timestamp . '.sql';
        $gzFilename = $filename . '.gz';
        $tmpPath    = storage_path('app/private/' . $filename);

        // Pastikan direktori ada
        if (!is_dir(storage_path('app/private'))) {
            mkdir(storage_path('app/private'), 0755, true);
        }

        // Tulis password ke file sementara agar tidak terekspos di command line
        $cnfPath = storage_path('app/private/.mysqldump_' . $timestamp . '.cnf');
        file_put_contents($cnfPath, "[mysqldump]\npassword=" . $dbPass . "\n");
        chmod($cnfPath, 0600);

        $command = sprintf(
            'mysqldump --defaults-extra-file=%s --host=%s --port=%s --user=%s --no-tablespaces --skip-comments --single-transaction %s > %s 2>&1',
            escapeshellarg($cnfPath),
            escapeshellarg($dbHost),
            escapeshellarg($dbPort),
            escapeshellarg($dbUser),
            escapeshellarg($dbName),
            escapeshellarg($tmpPath)
        );

        exec($command, $output, $returnCode);

        // Hapus file credentials segera
        @unlink($cnfPath);

        $outputStr = implode(' ', $output);

        if ($returnCode !== 0 || !file_exists($tmpPath) || filesize($tmpPath) === 0) {
            @unlink($tmpPath);
            return response()->json([
                'success' => false,
                'message' => 'Backup failed (code ' . $returnCode . '): ' . $outputStr,
            ], 500);
        }

        // Stream file + gzip on-the-fly, hapus tmp setelah selesai
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
            'X-Backup-Filename'   => $gzFilename,
            'X-Backup-Database'   => $dbName,
        ]);
    }
}
