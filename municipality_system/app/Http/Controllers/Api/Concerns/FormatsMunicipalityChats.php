<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Models\MunicipalityChatMessage;
use App\Models\MunicipalityChatThread;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;

trait FormatsMunicipalityChats
{
    private function closedChatDeletionMessage(): string
    {
        return 'تم إغلاق المحادثة. سيتم حذف هذه المحادثة تلقائياً بعد ساعتين إذا لم يرسل المواطن رسالة جديدة.';
    }

    private function pruneExpiredClosedThreads(?User $citizen = null): void
    {
        MunicipalityChatThread::query()
            ->when($citizen, fn ($query) => $query->where('citizen_id', $citizen->id))
            ->where('status', 'closed')
            ->whereNotNull('closed_at')
            ->where('closed_at', '<=', now()->subHours(2))
            ->delete();
    }

    private function workingHoursMessage(): string
    {
        return 'مرحباً، فريق البلدية يرد عادة خلال ساعات العمل الرسمية (9 صباحاً - 3 مساءً، الأحد-الخميس). سنقوم بالرد في أقرب وقت ممكن';
    }

    private function ensureWelcomeMessage(MunicipalityChatThread $thread): void
    {
        if ($thread->messages()->exists()) {
            return;
        }

        $thread->messages()->create([
            'sender_role' => 'system',
            'message_text' => $this->workingHoursMessage(),
            'is_system' => true,
        ]);
    }

    private function addOutsideWorkingHoursMessageIfNeeded(MunicipalityChatThread $thread): void
    {
        if (!$this->isOutsideWorkingHours()) {
            return;
        }

        $alreadySentToday = $thread->messages()
            ->where('is_system', true)
            ->where('message_text', $this->workingHoursMessage())
            ->whereDate('created_at', now('Africa/Tripoli')->toDateString())
            ->exists();

        if ($alreadySentToday) {
            return;
        }

        $thread->messages()->create([
            'sender_role' => 'system',
            'message_text' => $this->workingHoursMessage(),
            'is_system' => true,
        ]);
    }

    private function isOutsideWorkingHours(): bool
    {
        $now = now('Africa/Tripoli');

        return $now->isFriday()
            || $now->isSaturday()
            || $now->hour < 9
            || $now->hour >= 15;
    }

    private function storeChatImage($file): string
    {
        return Storage::url($file->store('municipality_chat', 'public'));
    }

    private function notifyUsers($users, string $title, string $body, MunicipalityChatThread $thread): void
    {
        foreach ($users as $user) {
            if (!$user) {
                continue;
            }

            Notification::create([
                'user_id' => $user->id,
                'title' => $title,
                'body' => $body,
                'type' => 'municipality_chat_message',
                'related_id' => $thread->id,
                'related_type' => MunicipalityChatThread::class,
            ]);
        }
    }

    private function receptionUsers()
    {
        return User::whereHas('role', fn ($query) => $query->where('role_name', 'reception'))
            ->where('is_active', true)
            ->get();
    }

    private function departmentUsers(int $departmentId)
    {
        return User::whereHas('role', fn ($query) => $query->where('role_name', 'department'))
            ->where('dept_id', $departmentId)
            ->where('is_active', true)
            ->get();
    }

    private function isStaffOnline(?MunicipalityChatThread $thread): bool
    {
        $cutoff = now()->subMinutes(10);
        $query = User::where('is_active', true)
            ->whereHas('tokens', fn ($tokenQuery) => $tokenQuery->where('last_used_at', '>=', $cutoff));

        if ($thread?->assigned_dept_id) {
            $query->whereHas('role', fn ($roleQuery) => $roleQuery->where('role_name', 'department'))
                ->where('dept_id', $thread->assigned_dept_id);
        } else {
            $query->whereHas('role', fn ($roleQuery) => $roleQuery->where('role_name', 'reception'));
        }

        return $query->exists();
    }

    private function formatThread(MunicipalityChatThread $thread, ?User $viewer = null): array
    {
        $thread->loadMissing([
            'citizen:id,full_name,email,phone',
            'assignedDepartment:id,dept_name',
            'messages.sender.role:id,role_name',
        ]);

        return [
            'id' => $thread->id,
            'status' => $thread->status,
            'status_label' => $this->threadStatusLabel($thread->status),
            'citizen_unread_count' => $thread->citizen_unread_count,
            'reception_unread_count' => $thread->reception_unread_count,
            'department_unread_count' => $thread->department_unread_count,
            'last_message_at' => optional($thread->last_message_at)->toISOString(),
            'closed_at' => optional($thread->closed_at)->toISOString(),
            'auto_delete_at' => $thread->closed_at ? $thread->closed_at->copy()->addHours(2)->toISOString() : null,
            'staff_online' => $this->isStaffOnline($thread),
            'citizen' => [
                'id' => $thread->citizen?->id,
                'full_name' => $thread->citizen?->full_name,
                'email' => $thread->citizen?->email,
                'phone' => $thread->citizen?->phone,
            ],
            'assigned_department' => $thread->assignedDepartment ? [
                'id' => $thread->assignedDepartment->id,
                'dept_name' => $thread->assignedDepartment->dept_name,
            ] : null,
            'messages' => $thread->messages
                ->sortBy('created_at')
                ->values()
                ->map(fn (MunicipalityChatMessage $message) => $this->formatMessage($message, $viewer))
                ->all(),
            'created_at' => optional($thread->created_at)->toISOString(),
            'updated_at' => optional($thread->updated_at)->toISOString(),
        ];
    }

    private function formatThreadSummary(MunicipalityChatThread $thread, string $viewerRole): array
    {
        $thread->loadMissing(['citizen:id,full_name,email,phone', 'assignedDepartment:id,dept_name']);
        $latest = $thread->messages()->latest()->first();

        return [
            'id' => $thread->id,
            'status' => $thread->status,
            'status_label' => $this->threadStatusLabel($thread->status),
            'unread_count' => match ($viewerRole) {
                'department' => $thread->department_unread_count,
                'citizen' => $thread->citizen_unread_count,
                default => $thread->reception_unread_count,
            },
            'last_message_at' => optional($thread->last_message_at)->toISOString(),
            'latest_message' => $latest?->message_text,
            'citizen' => [
                'id' => $thread->citizen?->id,
                'full_name' => $thread->citizen?->full_name,
                'email' => $thread->citizen?->email,
                'phone' => $thread->citizen?->phone,
            ],
            'assigned_department' => $thread->assignedDepartment ? [
                'id' => $thread->assignedDepartment->id,
                'dept_name' => $thread->assignedDepartment->dept_name,
            ] : null,
        ];
    }

    private function formatMessage(MunicipalityChatMessage $message, ?User $viewer = null): array
    {
        return [
            'id' => $message->id,
            'sender_id' => $message->sender_id,
            'sender_role' => $message->sender_role,
            'sender_label' => $this->senderLabel($message),
            'message_text' => $message->message_text,
            'image_url' => $message->image_url,
            'latitude' => $message->latitude,
            'longitude' => $message->longitude,
            'is_system' => $message->is_system,
            'is_mine' => $viewer ? $message->sender_id === $viewer->id : false,
            'created_at' => optional($message->created_at)->toISOString(),
        ];
    }

    private function senderLabel(MunicipalityChatMessage $message): string
    {
        if ($message->is_system || $message->sender_role === 'system') {
            return 'النظام';
        }

        return match ($message->sender_role) {
            'citizen' => 'المواطن',
            'department' => 'موظف القسم',
            'reception' => 'موظف الاستقبال',
            default => $message->sender?->full_name ?? 'مستخدم',
        };
    }

    private function threadStatusLabel(string $status): string
    {
        return match ($status) {
            'new' => 'بانتظار الرد',
            'active' => 'جارية',
            'closed' => 'مغلقة',
            default => $status,
        };
    }

    private function touchThread(MunicipalityChatThread $thread, string $status = 'active'): void
    {
        $thread->forceFill([
            'status' => $status,
            'last_message_at' => Carbon::now(),
            'closed_at' => null,
        ])->save();
    }
}
