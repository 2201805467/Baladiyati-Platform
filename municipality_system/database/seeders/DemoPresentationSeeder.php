<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Notification;
use App\Models\Rating;
use App\Models\Report;
use App\Models\ReportComment;
use App\Models\ReportImage;
use App\Models\ReportLog;
use App\Models\Suggestion;
use App\Models\SuggestionVote;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DemoPresentationSeeder extends Seeder
{
    public function run(): void
    {
        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $reception = User::where('email', 'reception@baladiyati.test')->first();

        $categories = Category::with('department')->get()->keyBy('category_name');

        $reports = [
            [
                'number' => 'DEMO-ROAD-001',
                'category' => 'Potholes',
                'status' => 'closed',
                'title' => 'حفرة عميقة قرب تقاطع رئيسي',
                'description' => 'حفرة واضحة في الطريق تسبب ازدحاماً وتحتاج إلى صيانة عاجلة.',
                'lat' => 32.887120,
                'lng' => 13.191250,
                'created_at' => now()->subDays(15),
                'transferred_at' => now()->subDays(14)->setTime(9, 30),
                'started_at' => now()->subDays(14)->setTime(10, 18),
                'closed_at' => now()->subDays(12)->setTime(16, 45),
                'completion_report' => 'تم ردم الحفرة وإعادة تسوية طبقة الإسفلت.',
                'rating' => 5,
            ],
            [
                'number' => 'DEMO-LIGHT-002',
                'category' => 'Broken streetlight',
                'status' => 'in_progress',
                'title' => 'عمود إنارة لا يعمل',
                'description' => 'الإنارة متوقفة في الشارع منذ عدة أيام.',
                'lat' => 32.891950,
                'lng' => 13.204800,
                'created_at' => now()->subDays(8),
                'transferred_at' => now()->subDays(7)->setTime(11, 15),
                'started_at' => now()->subDays(7)->setTime(13, 0),
            ],
            [
                'number' => 'DEMO-SAN-003',
                'category' => 'Garbage accumulation',
                'status' => 'pending',
                'title' => 'تراكم مخلفات بجانب الحاويات',
                'description' => 'تراكم كبير للمخلفات يحتاج إلى سيارة نظافة إضافية.',
                'lat' => 32.881400,
                'lng' => 13.215300,
                'created_at' => now()->subDays(5),
                'transferred_at' => now()->subDays(4)->setTime(8, 45),
                'started_at' => now()->subDays(4)->setTime(12, 10),
            ],
            [
                'number' => 'DEMO-SEW-004',
                'category' => 'Sewage leak',
                'status' => 'transferred',
                'title' => 'تسرب مياه صرف صحي',
                'description' => 'تسرب ظاهر قرب فتحة الصرف ويحتاج إلى كشف ميداني.',
                'lat' => 32.875900,
                'lng' => 13.198700,
                'created_at' => now()->subDays(3),
                'transferred_at' => now()->subDays(2)->setTime(10, 20),
            ],
            [
                'number' => 'DEMO-ROAD-005',
                'category' => 'Road damage',
                'status' => 'under_review',
                'title' => 'هبوط جزئي في الرصيف',
                'description' => 'يوجد هبوط في جزء من الرصيف قرب مدخل مدرسة.',
                'lat' => 32.899500,
                'lng' => 13.184600,
                'created_at' => now()->subDay()->setTime(9, 5),
            ],
            [
                'number' => 'DEMO-TREE-006',
                'category' => 'Fallen tree',
                'status' => 'new',
                'title' => 'شجرة ساقطة على جانب الطريق',
                'description' => 'الشجرة لا تغلق الطريق بالكامل لكنها تعيق ممر المشاة.',
                'lat' => 32.868300,
                'lng' => 13.225500,
                'created_at' => now()->subHours(6),
            ],
        ];

        Model::unguarded(function () use ($reports, $categories, $citizen, $reception) {
            DB::transaction(function () use ($reports, $categories, $citizen, $reception) {
            foreach ($reports as $item) {
                $category = $categories->get($item['category']);
                if (! $category) {
                    continue;
                }

                $report = Report::updateOrCreate(
                    ['report_number' => $item['number']],
                    [
                        'citizen_id' => $citizen->id,
                        'category_id' => $category->id,
                        'dept_id' => in_array($item['status'], ['new', 'under_review'], true) ? null : $category->dept_id,
                        'title' => $item['title'],
                        'description' => $item['description'],
                        'latitude' => $item['lat'],
                        'longitude' => $item['lng'],
                        'status' => $item['status'],
                        'ai_suggested_category' => $category->category_name,
                        'is_duplicate' => false,
                        'completion_report' => $item['completion_report'] ?? null,
                        'closed_at' => $item['closed_at'] ?? null,
                        'sla_due_at' => ($item['transferred_at'] ?? $item['created_at'])->copy()->addDays(3),
                        'created_at' => $item['created_at'],
                        'updated_at' => $item['closed_at'] ?? $item['started_at'] ?? $item['transferred_at'] ?? $item['created_at'],
                    ]
                );

                $this->replaceReportTimeline($report, $item, $citizen, $reception);
                $this->replaceReportMedia($report, $citizen, $item);
                $this->replaceReportRating($report, $citizen, $item);
            }

            $this->seedSuggestions($citizen, $reception);
            $this->seedNotifications($citizen);
            });
        });
    }

    private function replaceReportTimeline(Report $report, array $item, User $citizen, ?User $reception): void
    {
        ReportLog::where('report_id', $report->id)->delete();
        ReportComment::where('report_id', $report->id)->delete();

        ReportLog::create([
            'report_id' => $report->id,
            'action_by' => $citizen->id,
            'action' => 'created',
            'old_status' => null,
            'new_status' => 'new',
            'note' => 'Demo report created by citizen.',
            'created_at' => $item['created_at'],
        ]);

        if (($item['status'] ?? null) !== 'new') {
            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $reception?->id ?? $citizen->id,
                'action' => 'opened_for_review',
                'old_status' => 'new',
                'new_status' => 'under_review',
                'note' => 'Reception reviewed the report.',
                'created_at' => $item['created_at']->copy()->addHours(2),
            ]);
        }

        if (isset($item['transferred_at'])) {
            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $reception?->id ?? $citizen->id,
                'action' => 'transferred',
                'old_status' => 'under_review',
                'new_status' => 'transferred',
                'note' => 'Report transferred to the responsible department.',
                'created_at' => $item['transferred_at'],
            ]);
        }

        if (isset($item['started_at'])) {
            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $report->department?->account?->id ?? $reception?->id ?? $citizen->id,
                'action' => 'status_updated',
                'old_status' => 'transferred',
                'new_status' => $item['status'] === 'pending' ? 'pending' : 'in_progress',
                'note' => $item['status'] === 'pending'
                    ? 'Waiting for field equipment availability.'
                    : 'Field team started processing the report.',
                'created_at' => $item['started_at'],
            ]);
        }

        if (($item['status'] ?? null) === 'closed' && isset($item['closed_at'])) {
            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $report->department?->account?->id ?? $reception?->id ?? $citizen->id,
                'action' => 'closed',
                'old_status' => 'in_progress',
                'new_status' => 'closed',
                'note' => $item['completion_report'],
                'created_at' => $item['closed_at'],
            ]);
        }

        ReportComment::create([
            'report_id' => $report->id,
            'user_id' => $reception?->id ?? $citizen->id,
            'comment_text' => 'تم استلام البلاغ وإحالته حسب الاختصاص.',
            'created_at' => ($item['transferred_at'] ?? $item['created_at'])->copy()->addMinutes(30),
        ]);
    }

    private function replaceReportMedia(Report $report, User $citizen, array $item): void
    {
        ReportImage::where('report_id', $report->id)->delete();

        ReportImage::create([
            'report_id' => $report->id,
            'image_url' => '/storage/demo/reports/'.$report->report_number.'-before.jpg',
            'image_type' => 'before',
            'uploaded_by' => $citizen->id,
            'uploaded_at' => $item['created_at'],
        ]);

        if (($item['status'] ?? null) === 'closed') {
            ReportImage::create([
                'report_id' => $report->id,
                'image_url' => '/storage/demo/reports/'.$report->report_number.'-after.jpg',
                'image_type' => 'after',
                'uploaded_by' => $report->department?->account?->id ?? $citizen->id,
                'uploaded_at' => $item['closed_at'] ?? now(),
            ]);
        }
    }

    private function replaceReportRating(Report $report, User $citizen, array $item): void
    {
        Rating::where('report_id', $report->id)->delete();

        if (! isset($item['rating'])) {
            return;
        }

        Rating::create([
            'report_id' => $report->id,
            'citizen_id' => $citizen->id,
            'stars' => $item['rating'],
            'comment' => 'تمت معالجة البلاغ بشكل جيد.',
            'created_at' => ($item['closed_at'] ?? now())->copy()->addHours(3),
        ]);
    }

    private function seedSuggestions(User $citizen, ?User $reception): void
    {
        $suggestions = [
            [
                'title' => 'زيادة حاويات الفرز في الأحياء السكنية',
                'description' => 'توزيع حاويات فرز للنفايات القابلة للتدوير في نقاط واضحة داخل الأحياء.',
                'category' => 'environment',
                'status' => 'accepted',
                'progress' => 35,
                'note' => 'تمت إحالة المقترح لإدارة النظافة لإعداد خطة توزيع تجريبية.',
                'votes' => ['up' => 4, 'down' => 1],
            ],
            [
                'title' => 'إنارة ممشى الحي مساءً',
                'description' => 'إضافة أعمدة إنارة منخفضة الاستهلاك في ممشى الحي لتحسين السلامة.',
                'category' => 'lighting',
                'status' => 'under_review',
                'progress' => 0,
                'note' => null,
                'votes' => ['up' => 0, 'down' => 0],
            ],
            [
                'title' => 'ممر مشاة قرب المدرسة',
                'description' => 'إنشاء ممر مشاة واضح مع مطبات تهدئة أمام المدرسة الابتدائية.',
                'category' => 'roads',
                'status' => 'accepted',
                'progress' => 60,
                'note' => 'تمت الموافقة المبدئية وإدراج الموقع ضمن خطة السلامة المرورية.',
                'votes' => ['up' => 6, 'down' => 0],
            ],
        ];

        foreach ($suggestions as $item) {
            $suggestion = Suggestion::updateOrCreate(
                ['title' => $item['title'], 'citizen_id' => $citizen->id],
                [
                    'description' => $item['description'],
                    'category' => $item['category'],
                    'status' => $item['status'],
                    'reviewed_by' => $item['status'] === 'accepted' ? $reception?->id : null,
                    'implementation_status' => $item['status'] === 'accepted' ? 'in_progress' : null,
                    'implementation_progress_percent' => $item['progress'],
                    'implementation_note' => $item['note'],
                    'created_at' => now()->subDays($item['status'] === 'under_review' ? 2 : 20),
                    'updated_at' => now()->subDays($item['status'] === 'under_review' ? 2 : 5),
                ]
            );

            SuggestionVote::where('suggestion_id', $suggestion->id)->delete();

            if ($item['votes']['up'] > 0) {
                SuggestionVote::updateOrCreate(
                    ['suggestion_id' => $suggestion->id, 'citizen_id' => $citizen->id],
                    ['vote_type' => 'up']
                );
            }
        }
    }

    private function seedNotifications(User $citizen): void
    {
        Notification::updateOrCreate(
            [
                'user_id' => $citizen->id,
                'type' => 'demo_report_update',
                'related_type' => Report::class,
                'related_id' => Report::where('report_number', 'DEMO-ROAD-001')->value('id'),
            ],
            [
                'title' => 'تم إغلاق بلاغك',
                'body' => 'تمت معالجة بلاغ الحفرة وهو متاح للتقييم.',
                'is_read' => false,
                'created_at' => now()->subDays(12),
            ]
        );
    }
}
