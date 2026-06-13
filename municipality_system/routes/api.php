<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\Admin\AnalyticsController as AdminAnalyticsController;
use App\Http\Controllers\Api\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\Admin\DepartmentController as AdminDepartmentController;
use App\Http\Controllers\Api\Admin\EmergencyContactController as AdminEmergencyContactController;
use App\Http\Controllers\Api\Admin\ProjectController as AdminProjectController;
use App\Http\Controllers\Api\Admin\PublicFacilityController as AdminPublicFacilityController;
use App\Http\Controllers\Api\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\Citizen\NotificationController as CitizenNotificationController;
use App\Http\Controllers\Api\Citizen\PublicInfoController as CitizenPublicInfoController;
use App\Http\Controllers\Api\Citizen\ReportController as CitizenReportController;
use App\Http\Controllers\Api\Citizen\SuggestionController as CitizenSuggestionController;
use App\Http\Controllers\Api\Department\ReportController as DepartmentReportController;
use App\Http\Controllers\Api\Reception\ReportController as ReceptionReportController;
use App\Http\Controllers\Api\Reception\SuggestionController as ReceptionSuggestionController;
use Illuminate\Support\Facades\Route;

$todo = fn (string $feature) => fn () => response()->json([
    'message' => $feature.' endpoint is ready to implement.',
], 501);

Route::post('/auth/login', [AuthController::class, 'login'])->name('auth.login');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');
});

Route::middleware(['auth:sanctum', 'role:citizen'])
    ->prefix('citizen')
    ->name('citizen.')
    ->group(function () use ($todo) {
        Route::get('/reports', [CitizenReportController::class, 'index'])->name('reports.index');
        Route::post('/reports', [CitizenReportController::class, 'store'])->name('reports.store');
        Route::get('/reports/{report}', [CitizenReportController::class, 'show'])->name('reports.show');
        Route::post('/reports/{report}/comments', [CitizenReportController::class, 'storeComment'])->name('reports.comments.store');
        Route::post('/reports/{report}/rating', [CitizenReportController::class, 'storeRating'])->name('reports.rating.store');

        Route::get('/suggestions', [CitizenSuggestionController::class, 'index'])->name('suggestions.index');
        Route::post('/suggestions', [CitizenSuggestionController::class, 'store'])->name('suggestions.store');
        Route::post('/suggestions/{suggestion}/vote', [CitizenSuggestionController::class, 'vote'])->name('suggestions.vote');
        Route::delete('/suggestions/{suggestion}/vote', [CitizenSuggestionController::class, 'destroyVote'])->name('suggestions.vote.destroy');

        Route::get('/notifications', [CitizenNotificationController::class, 'index'])->name('notifications.index');
        Route::patch('/notifications/{notification}/read', [CitizenNotificationController::class, 'markAsRead'])->name('notifications.read');
        Route::patch('/notifications/read-all', [CitizenNotificationController::class, 'markAllAsRead'])->name('notifications.read-all');

        Route::get('/projects', [CitizenPublicInfoController::class, 'projects'])->name('projects.index');
        Route::get('/facilities', [CitizenPublicInfoController::class, 'facilities'])->name('facilities.index');
        Route::get('/emergency-contacts', [CitizenPublicInfoController::class, 'emergencyContacts'])->name('emergency-contacts.index');
    });

Route::middleware(['auth:sanctum', 'role:admin'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/users', [AdminUserController::class, 'index'])->name('users.index');
        Route::post('/users', [AdminUserController::class, 'store'])->name('users.store');
        Route::put('/users/{user}', [AdminUserController::class, 'update'])->name('users.update');
        Route::patch('/users/{user}/deactivate', [AdminUserController::class, 'deactivate'])->name('users.deactivate');

        Route::get('/departments', [AdminDepartmentController::class, 'index'])->name('departments.index');
        Route::post('/departments', [AdminDepartmentController::class, 'store'])->name('departments.store');
        Route::put('/departments/{department}', [AdminDepartmentController::class, 'update'])->name('departments.update');

        Route::get('/categories', [AdminCategoryController::class, 'index'])->name('categories.index');
        Route::post('/categories', [AdminCategoryController::class, 'store'])->name('categories.store');
        Route::put('/categories/{category}', [AdminCategoryController::class, 'update'])->name('categories.update');

        Route::get('/facilities', [AdminPublicFacilityController::class, 'index'])->name('facilities.index');
        Route::post('/facilities', [AdminPublicFacilityController::class, 'store'])->name('facilities.store');
        Route::put('/facilities/{facility}', [AdminPublicFacilityController::class, 'update'])->name('facilities.update');

        Route::get('/emergency-contacts', [AdminEmergencyContactController::class, 'index'])->name('emergency-contacts.index');
        Route::post('/emergency-contacts', [AdminEmergencyContactController::class, 'store'])->name('emergency-contacts.store');
        Route::put('/emergency-contacts/{emergencyContact}', [AdminEmergencyContactController::class, 'update'])->name('emergency-contacts.update');

        Route::get('/projects', [AdminProjectController::class, 'index'])->name('projects.index');
        Route::post('/projects', [AdminProjectController::class, 'store'])->name('projects.store');
        Route::put('/projects/{project}', [AdminProjectController::class, 'update'])->name('projects.update');

        Route::get('/analytics/reports', [AdminAnalyticsController::class, 'reports'])->name('analytics.reports');
        Route::get('/analytics/departments', [AdminAnalyticsController::class, 'departments'])->name('analytics.departments');
    });

Route::middleware(['auth:sanctum', 'role:reception'])
    ->prefix('reception')
    ->name('reception.')
    ->group(function () use ($todo) {
        Route::get('/reports', [ReceptionReportController::class, 'index'])->name('reports.index');
        Route::get('/reports/{report}', [ReceptionReportController::class, 'show'])->name('reports.show');
        Route::patch('/reports/{report}/classify', [ReceptionReportController::class, 'classify'])->name('reports.classify');
        Route::patch('/reports/{report}/assign', [ReceptionReportController::class, 'assign'])->name('reports.assign');

        Route::get('/suggestions', [ReceptionSuggestionController::class, 'index'])->name('suggestions.index');
        Route::patch('/suggestions/{suggestion}/accept', [ReceptionSuggestionController::class, 'accept'])->name('suggestions.accept');
        Route::patch('/suggestions/{suggestion}/reject', [ReceptionSuggestionController::class, 'reject'])->name('suggestions.reject');
    });

Route::middleware(['auth:sanctum', 'role:department'])
    ->prefix('department')
    ->name('department.')
    ->group(function () use ($todo) {
        Route::get('/reports', [DepartmentReportController::class, 'index'])->name('reports.index');
        Route::get('/reports/{report}', [DepartmentReportController::class, 'show'])->name('reports.show');
        Route::patch('/reports/{report}/status', [DepartmentReportController::class, 'updateStatus'])->name('reports.status.update');
        Route::post('/reports/{report}/comments', [DepartmentReportController::class, 'storeComment'])->name('reports.comments.store');
        Route::post('/reports/{report}/attachments', [DepartmentReportController::class, 'storeAttachment'])->name('reports.attachments.store');
        Route::patch('/reports/{report}/close', [DepartmentReportController::class, 'close'])->name('reports.close');
    });
