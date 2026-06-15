<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\Admin\AnalyticsController as AdminAnalyticsController;
use App\Http\Controllers\Api\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\Admin\DepartmentController as AdminDepartmentController;
use App\Http\Controllers\Api\Admin\EmergencyContactController as AdminEmergencyContactController;
use App\Http\Controllers\Api\Admin\PermissionController as AdminPermissionController;
use App\Http\Controllers\Api\Admin\ProjectController as AdminProjectController;
use App\Http\Controllers\Api\Admin\PublicFacilityController as AdminPublicFacilityController;
use App\Http\Controllers\Api\Admin\SecurityLogController as AdminSecurityLogController;
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
Route::post('/auth/register', [AuthController::class, 'register'])->name('auth.register');
Route::post('/auth/verify-otp', [AuthController::class, 'verifyOtp'])->name('auth.verify-otp');
Route::post('/auth/resend-otp', [AuthController::class, 'resendOtp'])->name('auth.resend-otp');
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->name('auth.forgot-password');
Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->name('auth.reset-password');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
    Route::put('/auth/profile', [AuthController::class, 'updateProfile'])->name('auth.profile.update');
    Route::put('/auth/change-password', [AuthController::class, 'changePassword'])->name('auth.password.change');
    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');

    Route::get('/notifications', [CitizenNotificationController::class, 'index'])->name('notifications.index');
    Route::patch('/notifications/read-all', [CitizenNotificationController::class, 'markAllAsRead'])->name('notifications.read-all');
    Route::patch('/notifications/{notification}/read', [CitizenNotificationController::class, 'markAsRead'])->name('notifications.read');
});

Route::middleware(['auth:sanctum', 'role:citizen'])
    ->prefix('citizen')
    ->name('citizen.')
    ->group(function () use ($todo) {
        Route::get('/reports', [CitizenReportController::class, 'index'])->middleware('permission:submit_reports')->name('reports.index');
        Route::get('/categories', [CitizenReportController::class, 'categories'])->middleware('permission:submit_reports')->name('categories.index');
        Route::post('/reports/similar', [CitizenReportController::class, 'similar'])->middleware('permission:submit_reports')->name('reports.similar');
        Route::post('/reports/classify-image', [CitizenReportController::class, 'classifyImage'])->middleware('permission:submit_reports')->name('reports.classify-image');
        Route::post('/reports', [CitizenReportController::class, 'store'])->middleware('permission:submit_reports')->name('reports.store');
        Route::get('/reports/{report}', [CitizenReportController::class, 'show'])->middleware('permission:submit_reports')->name('reports.show');
        Route::post('/reports/{report}/comments', [CitizenReportController::class, 'storeComment'])->middleware('permission:submit_reports')->name('reports.comments.store');
        Route::post('/reports/{report}/rating', [CitizenReportController::class, 'storeRating'])->middleware('permission:rate_reports')->name('reports.rating.store');

        Route::get('/suggestions', [CitizenSuggestionController::class, 'index'])->middleware('permission:submit_suggestions')->name('suggestions.index');
        Route::post('/suggestions', [CitizenSuggestionController::class, 'store'])->middleware('permission:submit_suggestions')->name('suggestions.store');
        Route::put('/suggestions/{suggestion}', [CitizenSuggestionController::class, 'update'])->middleware('permission:submit_suggestions')->name('suggestions.update');
        Route::delete('/suggestions/{suggestion}', [CitizenSuggestionController::class, 'destroy'])->middleware('permission:submit_suggestions')->name('suggestions.destroy');
        Route::post('/suggestions/{suggestion}/vote', [CitizenSuggestionController::class, 'vote'])->middleware('permission:vote_suggestions')->name('suggestions.vote');
        Route::delete('/suggestions/{suggestion}/vote', [CitizenSuggestionController::class, 'destroyVote'])->middleware('permission:vote_suggestions')->name('suggestions.vote.destroy');

        Route::get('/notifications', [CitizenNotificationController::class, 'index'])->name('notifications.index');
        Route::patch('/notifications/read-all', [CitizenNotificationController::class, 'markAllAsRead'])->name('notifications.read-all');
        Route::patch('/notifications/{notification}/read', [CitizenNotificationController::class, 'markAsRead'])->name('notifications.read');

        Route::get('/projects', [CitizenPublicInfoController::class, 'projects'])->name('projects.index');
        Route::get('/facilities', [CitizenPublicInfoController::class, 'facilities'])->name('facilities.index');
        Route::get('/emergency-contacts', [CitizenPublicInfoController::class, 'emergencyContacts'])->name('emergency-contacts.index');
    });

Route::middleware(['auth:sanctum', 'role:admin'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/users', [AdminUserController::class, 'index'])->middleware('permission:manage_users')->name('users.index');
        Route::post('/users', [AdminUserController::class, 'store'])->middleware('permission:manage_users')->name('users.store');
        Route::put('/users/{user}', [AdminUserController::class, 'update'])->middleware('permission:manage_users')->name('users.update');
        Route::patch('/users/{user}/deactivate', [AdminUserController::class, 'deactivate'])->middleware('permission:manage_users')->name('users.deactivate');
        Route::delete('/users/{user}', [AdminUserController::class, 'destroy'])->middleware('permission:manage_users')->name('users.destroy');

        Route::get('/roles', [AdminPermissionController::class, 'roles'])->middleware('permission:manage_permissions')->name('roles.index');
        Route::get('/permissions', [AdminPermissionController::class, 'permissions'])->middleware('permission:manage_permissions')->name('permissions.index');
        Route::put('/roles/{role}/permissions', [AdminPermissionController::class, 'updateRolePermissions'])->middleware('permission:manage_permissions')->name('roles.permissions.update');
        Route::get('/security-logs', [AdminSecurityLogController::class, 'index'])->middleware('permission:manage_permissions')->name('security-logs.index');

        Route::get('/departments', [AdminDepartmentController::class, 'index'])->middleware('permission:manage_departments')->name('departments.index');
        Route::post('/departments', [AdminDepartmentController::class, 'store'])->middleware('permission:manage_departments')->name('departments.store');
        Route::put('/departments/{department}', [AdminDepartmentController::class, 'update'])->middleware('permission:manage_departments')->name('departments.update');
        Route::delete('/departments/{department}', [AdminDepartmentController::class, 'destroy'])->middleware('permission:manage_departments')->name('departments.destroy');

        Route::get('/categories', [AdminCategoryController::class, 'index'])->middleware('permission:manage_categories')->name('categories.index');
        Route::post('/categories', [AdminCategoryController::class, 'store'])->middleware('permission:manage_categories')->name('categories.store');
        Route::put('/categories/{category}', [AdminCategoryController::class, 'update'])->middleware('permission:manage_categories')->name('categories.update');
        Route::delete('/categories/{category}', [AdminCategoryController::class, 'destroy'])->middleware('permission:manage_categories')->name('categories.destroy');

        Route::get('/facilities', [AdminPublicFacilityController::class, 'index'])->middleware('permission:manage_public_facilities')->name('facilities.index');
        Route::post('/facilities', [AdminPublicFacilityController::class, 'store'])->middleware('permission:manage_public_facilities')->name('facilities.store');
        Route::put('/facilities/{facility}', [AdminPublicFacilityController::class, 'update'])->middleware('permission:manage_public_facilities')->name('facilities.update');

        Route::get('/emergency-contacts', [AdminEmergencyContactController::class, 'index'])->middleware('permission:manage_public_facilities')->name('emergency-contacts.index');
        Route::post('/emergency-contacts', [AdminEmergencyContactController::class, 'store'])->middleware('permission:manage_public_facilities')->name('emergency-contacts.store');
        Route::put('/emergency-contacts/{emergencyContact}', [AdminEmergencyContactController::class, 'update'])->middleware('permission:manage_public_facilities')->name('emergency-contacts.update');

        Route::get('/projects', [AdminProjectController::class, 'index'])->middleware('permission:manage_projects')->name('projects.index');
        Route::post('/projects', [AdminProjectController::class, 'store'])->middleware('permission:manage_projects')->name('projects.store');
        Route::put('/projects/{project}', [AdminProjectController::class, 'update'])->middleware('permission:manage_projects')->name('projects.update');

        Route::get('/analytics/reports', [AdminAnalyticsController::class, 'reports'])->middleware('permission:view_analytics')->name('analytics.reports');
        Route::get('/analytics/departments', [AdminAnalyticsController::class, 'departments'])->middleware('permission:view_analytics')->name('analytics.departments');
        Route::get('/analytics/departments/{department}', [AdminAnalyticsController::class, 'departmentPerformance'])->middleware('permission:view_analytics')->name('analytics.departments.show');
    });

Route::middleware(['auth:sanctum', 'role:reception'])
    ->prefix('reception')
    ->name('reception.')
    ->group(function () use ($todo) {
        Route::get('/reports', [ReceptionReportController::class, 'index'])->middleware('permission:review_reports')->name('reports.index');
        Route::get('/reports/{report}', [ReceptionReportController::class, 'show'])->middleware('permission:review_reports')->name('reports.show');
        Route::patch('/reports/{report}/classify', [ReceptionReportController::class, 'classify'])->middleware('permission:review_reports')->name('reports.classify');
        Route::patch('/reports/{report}/assign', [ReceptionReportController::class, 'assign'])->middleware('permission:assign_reports')->name('reports.assign');
        Route::delete('/reports/{report}', [ReceptionReportController::class, 'reject'])->middleware('permission:review_reports')->name('reports.reject');

        Route::get('/suggestions', [ReceptionSuggestionController::class, 'index'])->middleware('permission:review_suggestions')->name('suggestions.index');
        Route::patch('/suggestions/{suggestion}/accept', [ReceptionSuggestionController::class, 'accept'])->middleware('permission:review_suggestions')->name('suggestions.accept');
        Route::patch('/suggestions/{suggestion}/reject', [ReceptionSuggestionController::class, 'reject'])->middleware('permission:review_suggestions')->name('suggestions.reject');
        Route::patch('/suggestions/{suggestion}/implementation', [ReceptionSuggestionController::class, 'updateImplementation'])->middleware('permission:review_suggestions')->name('suggestions.implementation.update');
    });

Route::middleware(['auth:sanctum', 'role:department'])
    ->prefix('department')
    ->name('department.')
    ->group(function () use ($todo) {
        Route::get('/reports', [DepartmentReportController::class, 'index'])->middleware('permission:process_department_reports')->name('reports.index');
        Route::get('/reports/{report}', [DepartmentReportController::class, 'show'])->middleware('permission:process_department_reports')->name('reports.show');
        Route::patch('/reports/{report}/status', [DepartmentReportController::class, 'updateStatus'])->middleware('permission:process_department_reports')->name('reports.status.update');
        Route::post('/reports/{report}/comments', [DepartmentReportController::class, 'storeComment'])->middleware('permission:process_department_reports')->name('reports.comments.store');
        Route::post('/reports/{report}/attachments', [DepartmentReportController::class, 'storeAttachment'])->middleware('permission:process_department_reports')->name('reports.attachments.store');
        Route::patch('/reports/{report}/close', [DepartmentReportController::class, 'close'])->middleware('permission:process_department_reports')->name('reports.close');
    });
