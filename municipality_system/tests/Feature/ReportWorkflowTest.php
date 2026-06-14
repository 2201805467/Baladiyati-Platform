<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Department;
use App\Models\Report;
use App\Models\SecurityLog;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
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

    private function fakePng(string $name): \Illuminate\Http\Testing\File
    {
        return UploadedFile::fake()->createWithContent(
            $name,
            base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=')
        );
    }
}
