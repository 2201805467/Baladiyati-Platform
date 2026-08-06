<?php

namespace App\Http\Controllers\Api\Reception;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\FormatsMunicipalityChats;
use App\Models\Department;
use App\Models\MunicipalityChatThread;
use Illuminate\Http\Request;

class MunicipalityChatController extends Controller
{
    use FormatsMunicipalityChats;

    public function index(Request $request)
    {
        $this->pruneExpiredClosedThreads();

        $threads = MunicipalityChatThread::with(['citizen:id,full_name,email,phone', 'assignedDepartment:id,dept_name'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->query('status')))
            ->orderByRaw('CASE WHEN reception_unread_count > 0 THEN 0 ELSE 1 END')
            ->orderByDesc('last_message_at')
            ->paginate(min((int) $request->query('per_page', 30), 50));

        return response()->json([
            'data' => $threads->getCollection()
                ->map(fn ($thread) => $this->formatThreadSummary($thread, 'reception'))
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
        $thread->forceFill(['reception_unread_count' => 0])->save();

        return response()->json([
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
            'can_reply' => $thread->assigned_dept_id === null && $thread->status !== 'closed',
        ]);
    }

    public function reply(MunicipalityChatThread $thread, Request $request)
    {
        if ($thread->assigned_dept_id !== null) {
            return response()->json(['message' => 'تم تحويل هذه المحادثة إلى القسم المختص، ولا يمكن لموظف الاستقبال الرد عليها.'], 403);
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
            'sender_role' => 'reception',
            'message_text' => $validated['message_text'] ?? null,
            'image_url' => $imageUrl,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
        ]);

        $thread->forceFill([
            'status' => 'active',
            'last_message_at' => now(),
            'closed_at' => null,
            'reception_unread_count' => 0,
            'citizen_unread_count' => $thread->citizen_unread_count + 1,
        ])->save();

        $this->notifyUsers([$thread->citizen], 'رد جديد من البلدية', 'وصل رد جديد في خدمة العملاء.', $thread);

        return response()->json([
            'message' => 'تم إرسال الرد بنجاح.',
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
        ]);
    }

    public function transfer(MunicipalityChatThread $thread, Request $request)
    {
        if ($thread->status === 'closed') {
            return response()->json(['message' => 'لا يمكن تحويل محادثة مغلقة.'], 422);
        }

        $validated = $request->validate([
            'dept_id' => ['required', 'exists:departments,id'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $department = Department::findOrFail($validated['dept_id']);

        $thread->forceFill([
            'assigned_dept_id' => $department->id,
            'status' => 'active',
            'last_message_at' => now(),
            'reception_unread_count' => 0,
            'department_unread_count' => $thread->department_unread_count + 1,
            'closed_at' => null,
        ])->save();

        $text = 'تم تحويل المحادثة إلى '.$department->dept_name.'.';
        if (!empty($validated['note'])) {
            $text .= ' ملاحظة: '.$validated['note'];
        }

        $thread->messages()->create([
            'sender_id' => $request->user()->id,
            'sender_role' => 'system',
            'message_text' => $text,
            'is_system' => true,
        ]);

        $this->notifyUsers(
            $this->departmentUsers($department->id),
            'محادثة محولة إلى قسمكم',
            'تم تحويل محادثة مواطن إلى قسمكم للرد عليها.',
            $thread
        );

        return response()->json([
            'message' => 'تم تحويل المحادثة بنجاح.',
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
        ]);
    }

    public function close(MunicipalityChatThread $thread, Request $request)
    {
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
}
