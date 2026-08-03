<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('polls', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('dept_id')->nullable()->constrained('departments')->nullOnDelete();
            $table->string('question', 255);
            $table->string('poll_type', 50)->default('quick');
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->boolean('is_geo_targeted')->default(false);
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->unsignedInteger('radius_meters')->nullable();
            $table->string('status', 30)->default('active');
            $table->text('cancel_reason')->nullable();
            $table->timestamps();
        });

        Schema::create('poll_options', function (Blueprint $table) {
            $table->id();
            $table->foreignId('poll_id')->constrained('polls')->cascadeOnDelete();
            $table->string('option_text', 150);
            $table->unsignedTinyInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('poll_votes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('poll_id')->constrained('polls')->cascadeOnDelete();
            $table->foreignId('poll_option_id')->constrained('poll_options')->cascadeOnDelete();
            $table->foreignId('citizen_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['poll_id', 'citizen_id'], 'poll_vote_once_unique');
        });

        Schema::create('poll_recipients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('poll_id')->constrained('polls')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->string('matched_by', 30)->default('general');
            $table->foreignId('notification_id')->nullable()->constrained('notifications')->nullOnDelete();
            $table->timestamps();
            $table->unique(['poll_id', 'user_id'], 'poll_recipient_unique');
        });

        DB::table('permissions')->updateOrInsert(
            ['permission_name' => 'manage_polls'],
            ['description' => 'Manage citizen polls and participatory surveys']
        );

        $permissionId = DB::table('permissions')->where('permission_name', 'manage_polls')->value('id');
        $roles = DB::table('roles')->whereIn('role_name', ['admin', 'reception'])->pluck('id');
        foreach ($roles as $roleId) {
            DB::table('role_permissions')->updateOrInsert([
                'role_id' => $roleId,
                'permission_id' => $permissionId,
            ]);
        }
    }

    public function down(): void
    {
        $permissionId = DB::table('permissions')->where('permission_name', 'manage_polls')->value('id');
        if ($permissionId) {
            DB::table('role_permissions')->where('permission_id', $permissionId)->delete();
            DB::table('permissions')->where('id', $permissionId)->delete();
        }

        Schema::dropIfExists('poll_recipients');
        Schema::dropIfExists('poll_votes');
        Schema::dropIfExists('poll_options');
        Schema::dropIfExists('polls');
    }
};
