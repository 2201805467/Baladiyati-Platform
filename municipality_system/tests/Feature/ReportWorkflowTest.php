<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Department;
use App\Mail\EmployeeCredentialsMail;
use App\Models\Notification;
use App\Models\Report;
use App\Models\Role;
use App\Models\SecurityLog;
use App\Models\Suggestion;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_report_workflow_can_be_completed(): void
    {
        $this->seed(DatabaseSeeder::class);
        Storage::fake('public');

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $reception = User::where('email', 'reception@baladiyati.test')->firstOrFail();

        $category = Category::where('category_name', 'Potholes')->firstOrFail();
        $department = Department::findOrFail($category->dept_id);

        Sanctum::actingAs($citizen);

        $createResponse = $this->postJson('/api/citizen/reports', [
            'title' => 'Large pothole near school',
            'description' => 'There is a large pothole blocking traffic.',
            'category_id' => $category->id,
            'area_id' => null,
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'severity' => 'high',
            'images' => [
                $this->fakePng('pothole.png'),
            ],
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('report.status', 'new')
            ->assertJsonPath('report.category_id', $category->id)
            ->assertJsonPath('report.dept_id', $department->id)
            ->assertJsonPath('report.sla_status', 'on_track')
            ->assertJsonPath('report.sla_color', 'green')
            ->assertJsonStructure([
                'report' => [
                    'sla_due_at',
                    'sla_status',
                    'sla_color',
                    'sla_remaining_seconds',
                    'sla_progress_percent',
                ],
            ]);

        $reportId = $createResponse->json('report.id');

        Sanctum::actingAs($reception);

        $this->patchJson("/api/reception/reports/{$reportId}/classify", [
            'category_id' => $category->id,
            'note' => 'Confirmed by reception.',
        ])->assertOk()
            ->assertJsonPath('report.status', 'under_review');

        $this->patchJson("/api/reception/reports/{$reportId}/assign", [
            'dept_id' => $department->id,
            'note' => 'Assigned to roads department.',
        ])->assertOk()
            ->assertJsonPath('report.status', 'transferred');

        $departmentAccount = User::where('email', 'department'.$department->id.'@baladiyati.test')->firstOrFail();
        Sanctum::actingAs($departmentAccount);

        $this->patchJson("/api/department/reports/{$reportId}/status", [
            'status' => 'in_progress',
            'note' => 'Team dispatched.',
        ])->assertOk()
            ->assertJsonPath('report.status', 'in_progress');

        $this->postJson("/api/department/reports/{$reportId}/comments", [
            'comment_text' => 'Maintenance team is working on the issue.',
        ])->assertCreated();

        $this->patchJson("/api/department/reports/{$reportId}/close", [
            'completion_report' => 'The road maintenance team repaired the pothole.',
            'completion_image' => $this->fakePng('completed.png'),
        ])->assertOk()
            ->assertJsonPath('report.status', 'closed');

        Sanctum::actingAs($citizen);

        $this->postJson("/api/citizen/reports/{$reportId}/rating", [
            'stars' => 5,
            'comment' => 'Fast response.',
        ])->assertOk()
            ->assertJsonPath('rating.stars', 5);

        $report = Report::with(['logs', 'comments', 'rating'])->findOrFail($reportId);

        $this->assertSame('closed', $report->status);
        $this->assertNotNull($report->closed_at);
        $this->assertSame(5, $report->rating->stars);
        $this->assertGreaterThanOrEqual(5, $report->logs->count());
        $this->assertCount(1, $report->comments);
    }

    public function test_login_returns_sanctum_token(): void
    {
        $this->seed(DatabaseSeeder::class);

        $response = $this->postJson('/api/auth/login', [
            'login' => 'citizen@baladiyati.test',
            'password' => 'password',
            'device_name' => 'feature-test',
        ]);

        $response->assertOk()
            ->assertJsonPath('token_type', 'Bearer')
            ->assertJsonPath('user.role.role_name', 'citizen')
            ->assertJsonStructure(['access_token']);
    }

    public function test_permission_denial_is_logged(): void
    {
        $this->seed(DatabaseSeeder::class);

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $citizen->role->permissions()->detach();

        Sanctum::actingAs($citizen);

        $this->getJson('/api/citizen/reports')
            ->assertForbidden()
            ->assertJsonPath('message', 'You do not have permission to perform this action.');

        $this->assertTrue(SecurityLog::where('user_id', $citizen->id)
            ->where('status', 'denied')
            ->where('action', 'permission_denied:submit_reports')
            ->exists());
    }

    public function test_department_delete_is_blocked_when_linked_to_categories(): void
    {
        $this->seed(DatabaseSeeder::class);

        $admin = User::where('email', 'admin@baladiyati.test')->firstOrFail();
        $department = Department::whereHas('categories')->firstOrFail();

        Sanctum::actingAs($admin);

        $this->deleteJson("/api/admin/departments/{$department->id}", [
            'confirm' => true,
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'Department cannot be deleted while users are linked to it.');
    }

    public function test_similar_report_requires_join_or_independent_choice(): void
    {
        $this->seed(DatabaseSeeder::class);
        Storage::fake('public');

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();

        Sanctum::actingAs($citizen);

        $this->postJson('/api/citizen/reports', [
            'title' => 'Pothole on main road',
            'category_id' => $category->id,
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'images' => [$this->fakePng('first.png')],
        ])->assertCreated();

        $this->postJson('/api/citizen/reports', [
            'title' => 'Same pothole from another angle',
            'category_id' => $category->id,
            'latitude' => 32.88725,
            'longitude' => 13.19135,
            'images' => [$this->fakePng('second.png')],
        ])->assertStatus(409)
            ->assertJsonPath('has_similar', true)
            ->assertJsonCount(1, 'similar_reports');
    }

    public function test_citizen_can_fetch_active_report_categories(): void
    {
        $this->seed(DatabaseSeeder::class);

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();

        Sanctum::actingAs($citizen);

        $this->getJson('/api/citizen/categories')
            ->assertOk()
            ->assertJsonStructure([
                'categories' => [
                    '*' => [
                        'id',
                        'category_name',
                        'department',
                    ],
                ],
            ]);
    }

    public function test_citizen_can_join_similar_report(): void
    {
        $this->seed(DatabaseSeeder::class);
        Storage::fake('public');

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();

        Sanctum::actingAs($citizen);

        $parentId = $this->postJson('/api/citizen/reports', [
            'title' => 'Broken road surface',
            'category_id' => $category->id,
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'images' => [$this->fakePng('parent.png')],
        ])->assertCreated()
            ->json('report.id');

        $this->postJson('/api/citizen/reports', [
            'title' => 'Joining the same road issue',
            'category_id' => $category->id,
            'latitude' => 32.88725,
            'longitude' => 13.19135,
            'duplicate_action' => 'join',
            'parent_report_id' => $parentId,
            'images' => [$this->fakePng('duplicate.png')],
        ])->assertCreated()
            ->assertJsonPath('report.is_duplicate', true)
            ->assertJsonPath('report.parent_report_id', $parentId);
    }

    public function test_report_image_classification_returns_category_contract(): void
    {
        $this->seed(DatabaseSeeder::class);

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();

        Sanctum::actingAs($citizen);

        $this->postJson('/api/citizen/reports/classify-image', [
            'image' => $this->fakePng('pothole.png'),
        ])->assertOk()
            ->assertJsonPath('classification.provider', 'local_keyword')
            ->assertJsonPath('classification.suggested_category.id', $category->id)
            ->assertJsonPath('classification.needs_manual_review', false)
            ->assertJsonStructure([
                'classification' => [
                    'provider',
                    'suggested_category' => [
                        'id',
                        'category_name',
                        'department',
                    ],
                    'confidence',
                    'needs_manual_review',
                    'manual_review_threshold',
                    'alternatives',
                    'reasoning',
                ],
            ]);
    }

    public function test_admin_can_create_employee_with_generated_password_email(): void
    {
        $this->seed(DatabaseSeeder::class);
        Mail::fake();

        $admin = User::where('email', 'admin@baladiyati.test')->firstOrFail();
        $receptionRole = Role::where('role_name', 'reception')->firstOrFail();

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/admin/users', [
            'full_name' => 'New Reception Officer',
            'email' => 'new.reception@baladiyati.test',
            'phone' => '0919999999',
            'employee_number' => 'REC-0999',
            'role_id' => $receptionRole->id,
        ])->assertCreated()
            ->assertJsonPath('user.employee_number', 'REC-0999')
            ->assertJsonPath('credentials_sent', true)
            ->assertJsonStructure(['dev_password']);

        $userId = $response->json('user.id');
        $created = User::findOrFail($userId);

        Mail::assertSent(EmployeeCredentialsMail::class, function (EmployeeCredentialsMail $mail) use ($created) {
            return $mail->hasTo($created->email) && $mail->user->is($created);
        });
    }

    public function test_admin_can_view_security_logs(): void
    {
        $this->seed(DatabaseSeeder::class);

        $admin = User::where('email', 'admin@baladiyati.test')->firstOrFail();

        SecurityLog::create([
            'user_id' => $admin->id,
            'action' => 'permission_denied:test',
            'ip_address' => '127.0.0.1',
            'status' => 'denied',
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/security-logs?status=denied')
            ->assertOk()
            ->assertJsonPath('data.0.status', 'denied')
            ->assertJsonPath('data.0.user.employee_number', 'ADM-0001');
    }

    public function test_department_is_notified_when_report_is_assigned_and_citizen_replies(): void
    {
        $this->seed(DatabaseSeeder::class);
        Storage::fake('public');

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $reception = User::where('email', 'reception@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();
        $department = Department::findOrFail($category->dept_id);
        $departmentAccount = User::where('dept_id', $department->id)->firstOrFail();

        Sanctum::actingAs($citizen);

        $reportId = $this->postJson('/api/citizen/reports', [
            'title' => 'Road issue needing assignment',
            'category_id' => $category->id,
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'images' => [$this->fakePng('road.png')],
        ])->assertCreated()
            ->json('report.id');

        Sanctum::actingAs($reception);

        $this->patchJson("/api/reception/reports/{$reportId}/assign", [
            'dept_id' => $department->id,
        ])->assertOk();

        $this->assertTrue(Notification::where('user_id', $departmentAccount->id)
            ->where('type', 'department_report_assigned')
            ->where('related_id', $reportId)
            ->exists());

        Sanctum::actingAs($citizen);

        $this->postJson("/api/citizen/reports/{$reportId}/comments", [
            'comment_text' => 'Here is another detail from the location.',
        ])->assertCreated();

        $this->assertTrue(Notification::where('user_id', $departmentAccount->id)
            ->where('type', 'citizen_report_comment')
            ->where('related_id', $reportId)
            ->exists());
    }

    public function test_reception_can_update_accepted_suggestion_implementation(): void
    {
        $this->seed(DatabaseSeeder::class);

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $reception = User::where('email', 'reception@baladiyati.test')->firstOrFail();

        $suggestion = Suggestion::create([
            'citizen_id' => $citizen->id,
            'title' => 'Add more street lights',
            'description' => 'The neighborhood needs more lighting.',
            'category' => 'lighting',
            'status' => 'under_review',
        ]);

        Sanctum::actingAs($reception);

        $this->patchJson("/api/reception/suggestions/{$suggestion->id}/accept")
            ->assertOk()
            ->assertJsonPath('suggestion.status', 'accepted');

        $this->patchJson("/api/reception/suggestions/{$suggestion->id}/implementation", [
            'implementation_status' => 'in_progress',
            'implementation_progress_percent' => 40,
            'implementation_note' => 'Initial field survey completed.',
        ])->assertOk()
            ->assertJsonPath('suggestion.implementation_status', 'in_progress')
            ->assertJsonPath('suggestion.implementation_progress_percent', 40);

        $this->assertTrue(Notification::where('user_id', $citizen->id)
            ->where('type', 'suggestion_implementation')
            ->where('related_id', $suggestion->id)
            ->exists());
    }

    public function test_sla_escalation_command_notifies_admin_once(): void
    {
        $this->seed(DatabaseSeeder::class);

        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $admin = User::where('email', 'admin@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();

        $report = Report::create([
            'report_number' => 'REP-OVERDUE-0001',
            'citizen_id' => $citizen->id,
            'category_id' => $category->id,
            'dept_id' => $category->dept_id,
            'title' => 'Overdue road issue',
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'severity' => 'high',
            'status' => 'in_progress',
            'sla_due_at' => now()->subHour(),
        ]);

        Artisan::call('reports:escalate-sla');
        Artisan::call('reports:escalate-sla');

        $this->assertSame(1, Notification::where('user_id', $admin->id)
            ->where('type', 'report_sla_overdue')
            ->where('related_id', $report->id)
            ->count());

        $this->assertSame(1, $report->logs()
            ->where('action', 'sla_escalated')
            ->count());
    }

    public function test_admin_can_view_department_performance_report_and_export_csv(): void
    {
        $this->seed(DatabaseSeeder::class);

        $admin = User::where('email', 'admin@baladiyati.test')->firstOrFail();
        $citizen = User::where('email', 'citizen@baladiyati.test')->firstOrFail();
        $category = Category::where('category_name', 'Potholes')->firstOrFail();
        $department = Department::findOrFail($category->dept_id);

        Report::create([
            'report_number' => 'REP-ANALYTICS-001',
            'citizen_id' => $citizen->id,
            'category_id' => $category->id,
            'dept_id' => $department->id,
            'title' => 'Closed analytics report',
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'severity' => 'medium',
            'status' => 'closed',
            'closed_at' => now(),
            'sla_due_at' => now()->addDay(),
        ]);

        Report::create([
            'report_number' => 'REP-ANALYTICS-002',
            'citizen_id' => $citizen->id,
            'category_id' => $category->id,
            'dept_id' => $department->id,
            'title' => 'Open analytics report',
            'latitude' => 32.8872,
            'longitude' => 13.1913,
            'severity' => 'medium',
            'status' => 'in_progress',
            'sla_due_at' => now()->addDay(),
        ]);

        Sanctum::actingAs($admin);

        $this->getJson("/api/admin/analytics/departments/{$department->id}")
            ->assertOk()
            ->assertJsonPath('department.id', $department->id)
            ->assertJsonPath('total_reports', 2)
            ->assertJsonPath('closed_reports', 1)
            ->assertJsonPath('completion_rate', 50);

        $this->get("/api/admin/analytics/departments/{$department->id}?format=csv")
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    private function fakePng(string $name): \Illuminate\Http\Testing\File
    {
        return UploadedFile::fake()->createWithContent(
            $name,
            base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=')
        );
    }
}
