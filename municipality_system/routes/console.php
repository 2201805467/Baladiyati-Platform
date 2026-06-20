<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use App\Models\Notification;
use App\Models\Report;
use App\Models\ReportLog;
use App\Models\User;
use Symfony\Component\Console\Command\Command;
use Illuminate\Support\Facades\Schedule;

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

    $activeReports = Report::with(['department', 'category'])
        ->whereNotIn('status', ['closed', 'rejected'])
        ->whereNotNull('sla_due_at')
        ->get();

    $departmentWarningCount = 0;
    $departmentOverdueCount = 0;

    foreach ($activeReports as $report) {
        if (! $report->dept_id || ! $report->created_at || ! $report->sla_due_at) {
            continue;
        }

        $totalSeconds = max(1, $report->created_at->diffInSeconds($report->sla_due_at, false));
        $remainingSeconds = now()->diffInSeconds($report->sla_due_at, false);
        $isOverdue = $remainingSeconds <= 0;
        $isApproaching = ! $isOverdue && $remainingSeconds <= ($totalSeconds * 0.25);

        if (! $isOverdue && ! $isApproaching) {
            continue;
        }

        $departmentUsers = User::where('dept_id', $report->dept_id)
            ->where('is_active', true)
            ->get();

        foreach ($departmentUsers as $user) {
            $notification = Notification::firstOrCreate(
                [
                    'user_id' => $user->id,
                    'type' => $isOverdue ? 'report_sla_overdue_department' : 'report_sla_warning',
                    'related_id' => $report->id,
                    'related_type' => Report::class,
                ],
                [
                    'title' => $isOverdue ? 'SLA overdue' : 'SLA warning',
                    'body' => $isOverdue
                        ? 'Report '.$report->report_number.' has exceeded its SLA deadline.'
                        : 'Report '.$report->report_number.' is close to its SLA deadline.',
                    'is_read' => false,
                ]
            );

            if ($notification->wasRecentlyCreated) {
                $isOverdue ? $departmentOverdueCount++ : $departmentWarningCount++;
            }
        }
    }

    $reports = $activeReports
        ->filter(fn (Report $report) => now()->greaterThanOrEqualTo($report->sla_due_at))
        ->filter(fn (Report $report) => ! $report->logs()->where('action', 'sla_escalated')->exists());

    foreach ($reports as $report) {
        $report->loadMissing(['department', 'category']);

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

    $this->info('Department SLA warning notification(s): '.$departmentWarningCount);
    $this->info('Department SLA overdue notification(s): '.$departmentOverdueCount);
    $this->info('Escalated '.$reports->count().' overdue report(s) to admin users.');

    return Command::SUCCESS;
})->purpose('Notify departments and admins about report SLA warnings and overdue reports');

Schedule::command('reports:escalate-sla')->everyFiveMinutes();
