<?php

use App\Http\Controllers\Api\AuthController;
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
        Route::get('/reports', $todo('Citizen reports list'))->name('reports.index');
        Route::post('/reports', $todo('Citizen report creation'))->name('reports.store');
        Route::get('/reports/{report}', $todo('Citizen report details'))->name('reports.show');
        Route::post('/reports/{report}/comments', $todo('Citizen report comment creation'))->name('reports.comments.store');
        Route::post('/reports/{report}/rating', $todo('Citizen report rating'))->name('reports.rating.store');

        Route::get('/suggestions', $todo('Citizen suggestions list'))->name('suggestions.index');
        Route::post('/suggestions', $todo('Citizen suggestion creation'))->name('suggestions.store');
        Route::post('/suggestions/{suggestion}/vote', $todo('Citizen suggestion voting'))->name('suggestions.vote');
        Route::delete('/suggestions/{suggestion}/vote', $todo('Citizen suggestion vote cancellation'))->name('suggestions.vote.destroy');

        Route::get('/notifications', $todo('Citizen notifications'))->name('notifications.index');
        Route::get('/projects', $todo('Citizen municipality projects'))->name('projects.index');
        Route::get('/facilities', $todo('Citizen public facilities'))->name('facilities.index');
        Route::get('/emergency-contacts', $todo('Citizen emergency contacts'))->name('emergency-contacts.index');
    });

Route::middleware(['auth:sanctum', 'role:admin'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () use ($todo) {
        Route::get('/users', $todo('Admin users list'))->name('users.index');
        Route::post('/users', $todo('Admin employee account creation'))->name('users.store');
        Route::put('/users/{user}', $todo('Admin user update'))->name('users.update');
        Route::patch('/users/{user}/deactivate', $todo('Admin user deactivation'))->name('users.deactivate');

        Route::get('/departments', $todo('Admin departments list'))->name('departments.index');
        Route::post('/departments', $todo('Admin department creation'))->name('departments.store');
        Route::put('/departments/{department}', $todo('Admin department update'))->name('departments.update');

        Route::get('/categories', $todo('Admin categories list'))->name('categories.index');
        Route::post('/categories', $todo('Admin category creation'))->name('categories.store');
        Route::put('/categories/{category}', $todo('Admin category update'))->name('categories.update');

        Route::get('/facilities', $todo('Admin public facilities list'))->name('facilities.index');
        Route::post('/facilities', $todo('Admin public facility creation'))->name('facilities.store');
        Route::put('/facilities/{facility}', $todo('Admin public facility update'))->name('facilities.update');

        Route::get('/projects', $todo('Admin municipality projects list'))->name('projects.index');
        Route::post('/projects', $todo('Admin municipality project creation'))->name('projects.store');
        Route::put('/projects/{project}', $todo('Admin municipality project update'))->name('projects.update');

        Route::get('/analytics/reports', $todo('Admin report analytics'))->name('analytics.reports');
        Route::get('/analytics/departments', $todo('Admin department performance analytics'))->name('analytics.departments');
    });

Route::middleware(['auth:sanctum', 'role:reception'])
    ->prefix('reception')
    ->name('reception.')
    ->group(function () use ($todo) {
        Route::get('/reports', $todo('Reception incoming reports list'))->name('reports.index');
        Route::get('/reports/{report}', $todo('Reception report details'))->name('reports.show');
        Route::patch('/reports/{report}/classify', $todo('Reception report classification'))->name('reports.classify');
        Route::patch('/reports/{report}/assign', $todo('Reception report assignment'))->name('reports.assign');

        Route::get('/suggestions', $todo('Reception suggestions list'))->name('suggestions.index');
        Route::patch('/suggestions/{suggestion}/accept', $todo('Reception suggestion acceptance'))->name('suggestions.accept');
        Route::patch('/suggestions/{suggestion}/reject', $todo('Reception suggestion rejection'))->name('suggestions.reject');
    });

Route::middleware(['auth:sanctum', 'role:department'])
    ->prefix('department')
    ->name('department.')
    ->group(function () use ($todo) {
        Route::get('/reports', $todo('Department assigned reports list'))->name('reports.index');
        Route::get('/reports/{report}', $todo('Department report details'))->name('reports.show');
        Route::patch('/reports/{report}/status', $todo('Department report status update'))->name('reports.status.update');
        Route::post('/reports/{report}/comments', $todo('Department report comment creation'))->name('reports.comments.store');
        Route::post('/reports/{report}/attachments', $todo('Department report attachment upload'))->name('reports.attachments.store');
        Route::patch('/reports/{report}/close', $todo('Department report closing'))->name('reports.close');
    });
