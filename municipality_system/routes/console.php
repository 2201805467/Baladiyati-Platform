<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Models\Notification;
use App\Models\Report;
use App\Models\ReportLog;
use App\Models\User;
use Symfony\Component\Console\Command\Command;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('reports:escalate-sla', function () {
    $admins = User::whereHas('role', fn ($query) => $query->where('role_name', 'admin'))->get();
    $systemActor = $admins->first();

    if (! $systemActor) {
        $this->warn('No admin account found for SLA escalation.');

        return Command::FAILURE;
    }

    $reports = Report::with(['department', 'category'])
        ->whereNotIn('status', ['closed', 'rejected'])
        ->whereNotNull('sla_due_at')
        ->where('sla_due_at', '<=', now())
        ->whereDoesntHave('logs', fn ($query) => $query->where('action', 'sla_escalated'))
        ->get();

    foreach ($reports as $report) {
        foreach ($admins as $admin) {
            Notification::firstOrCreate(
                [
                    'user_id' => $admin->id,
                    'type' => 'report_sla_overdue',
                    'related_id' => $report->id,
                    'related_type' => Report::class,
                ],
                [
                    'title' => 'SLA overdue report',
                    'body' => 'Report '.$report->report_number.' has exceeded its SLA deadline.',
                    'is_read' => false,
                ]
            );
        }

        ReportLog::create([
            'report_id' => $report->id,
            'action_by' => $systemActor->id,
            'action' => 'sla_escalated',
            'old_status' => $report->status,
            'new_status' => $report->status,
            'note' => 'SLA overdue escalation sent to admin users.',
        ]);
    }

    $this->info('Escalated '.$reports->count().' overdue report(s).');

    return Command::SUCCESS;
})->purpose('Notify admins about reports that exceeded their SLA deadline');
