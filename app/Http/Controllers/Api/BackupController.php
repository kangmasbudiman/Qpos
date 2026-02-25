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

        // Escape password untuk shell agar aman
        $escapedPass = escapeshellarg($dbPass);
        $escapedUser = escapeshellarg($dbUser);
        $escapedDb   = escapeshellarg($dbName);
        $escapedHost = escapeshellarg($dbHost);
        $escapedPort = escapeshellarg($dbPort);

        $command = "mysqldump"
            . " --host={$dbHost}"
            . " --port={$dbPort}"
            . " --user={$dbUser}"
            . " --password={$dbPass}"
            . " --no-tablespaces"
            . " --skip-comments"
            . " --single-transaction"
            . " {$dbName}"
            . " > " . escapeshellarg($tmpPath)
            . " 2>&1";

        exec($command, $output, $returnCode);

        if ($returnCode !== 0 || !file_exists($tmpPath) || filesize($tmpPath) === 0) {
            @unlink($tmpPath);
            return response()->json([
                'success' => false,
                'message' => 'Backup failed: ' . implode(' ', $output),
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
