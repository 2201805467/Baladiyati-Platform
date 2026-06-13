<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Department;
use App\Models\Report;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_report_workflow_can_be_completed(): void
    {
        $this->seed(DatabaseSeeder::class);

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
        ]);

        $createResponse->assertCreated()
            ->assertJsonPath('report.status', 'new')
            ->assertJsonPath('report.category_id', $category->id)
            ->assertJsonPath('report.dept_id', $department->id);

        $reportId = $createResponse->json('report.id');

        Sanctum::actingAs($reception);

        $this->patchJson("/api/reception/reports/{$reportId}/classify", [
            'category_id' => $category->id,
            'note' => 'Confirmed by reception.',
        ])->assertOk()
            ->assertJsonPath('report.status', 'reviewed');

        $this->patchJson("/api/reception/reports/{$reportId}/assign", [
            'dept_id' => $department->id,
            'note' => 'Assigned to roads department.',
        ])->assertOk()
            ->assertJsonPath('report.status', 'assigned');

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
            'note' => 'Issue resolved.',
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
}
