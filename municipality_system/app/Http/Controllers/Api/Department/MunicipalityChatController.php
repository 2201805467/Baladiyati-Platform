<?php

namespace App\Http\Controllers\Api\Department;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\FormatsMunicipalityChats;
use App\Models\MunicipalityChatThread;
use Illuminate\Http\Request;

class MunicipalityChatController extends Controller
{
    use FormatsMunicipalityChats;

    public function index(Request $request)
    {
        $this->pruneExpiredClosedThreads();

        $deptId = $request->user()->dept_id;

        $threads = MunicipalityChatThread::with(['citizen:id,full_name,email,phone', 'assignedDepartment:id,dept_name'])
            ->where('assigned_dept_id', $deptId)
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->query('status')))
            ->orderByRaw('CASE WHEN department_unread_count > 0 THEN 0 ELSE 1 END')
            ->orderByDesc('last_message_at')
            ->paginate(min((int) $request->query('per_page', 30), 50));

        return response()->json([
            'data' => $threads->getCollection()
                ->map(fn ($thread) => $this->formatThreadSummary($thread, 'department'))
                ->values(),
            'meta' => [
                'current_page' => $threads->currentPage(),
                'last_page' => $threads->lastPage(),
                'total' => $threads->total(),
            ],
        ]);
    }

    public function show(MunicipalityChatThread $thread, Request $request)
    {
        $this->authorizeDepartmentThread($thread, $request);
        $thread->forceFill(['department_unread_count' => 0])->save();

        return response()->json([
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
            'can_reply' => $thread->status !== 'closed',
        ]);
    }

    public function reply(MunicipalityChatThread $thread, Request $request)
    {
        $this->authorizeDepartmentThread($thread, $request);

        if ($thread->status === 'closed') {
            return response()->json(['message' => 'لا يمكن الرد على محادثة مغلقة.'], 422);
        }

        $validated = $request->validate([
            'message_text' => ['nullable', 'string', 'max:2000', 'required_without_all:image,latitude,longitude'],
            'image' => ['nullable', 'image', 'max:5120'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        $imageUrl = $request->hasFile('image') ? $this->storeChatImage($request->file('image')) : null;

        $thread->messages()->create([
            'sender_id' => $request->user()->id,
            'sender_role' => 'department',
            'message_text' => $validated['message_text'] ?? null,
            'image_url' => $imageUrl,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
        ]);

        $thread->forceFill([
            'status' => 'active',
            'last_message_at' => now(),
            'department_unread_count' => 0,
            'citizen_unread_count' => $thread->citizen_unread_count + 1,
        ])->save();

        $this->notifyUsers([$thread->citizen], 'رد جديد من البلدية', 'وصل رد جديد من القسم المختص في خدمة العملاء.', $thread);

        return response()->json([
            'message' => 'تم إرسال الرد بنجاح.',
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
        ]);
    }

    public function close(MunicipalityChatThread $thread, Request $request)
    {
        $this->authorizeDepartmentThread($thread, $request);

        $thread->messages()->create([
            'sender_id' => $request->user()->id,
            'sender_role' => 'system',
            'message_text' => $this->closedChatDeletionMessage(),
            'is_system' => true,
        ]);

        $thread->forceFill([
            'status' => 'closed',
            'closed_at' => now(),
            'last_message_at' => now(),
        ])->save();

        return response()->json([
            'message' => $this->closedChatDeletionMessage(),
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
        ]);
    }

    private function authorizeDepartmentThread(MunicipalityChatThread $thread, Request $request): void
    {
        abort_unless((int) $thread->assigned_dept_id === (int) $request->user()->dept_id, 403, 'هذه المحادثة غير محولة إلى قسمك.');
    }
}
