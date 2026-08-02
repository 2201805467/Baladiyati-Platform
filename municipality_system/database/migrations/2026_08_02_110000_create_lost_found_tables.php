<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('lost_found_items')) {
            Schema::create('lost_found_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('item_type', 20);
                $table->string('category', 40);
                $table->string('title', 200);
                $table->text('description');
                $table->string('image_url')->nullable();
                $table->decimal('latitude', 10, 7);
                $table->decimal('longitude', 10, 7);
                $table->string('area_name')->nullable();
                $table->date('incident_date')->nullable();
                $table->string('pet_type')->nullable();
                $table->text('pet_identifying_marks')->nullable();
                $table->boolean('pet_has_collar')->nullable();
                $table->string('status', 30)->default('active');
                $table->timestamp('resolved_at')->nullable();
                $table->timestamp('expires_at')->nullable();
                $table->foreignId('removed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('removed_at')->nullable();
                $table->text('removal_reason')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('lost_found_comments')) {
            Schema::create('lost_found_comments', function (Blueprint $table) {
                $table->id();
                $table->foreignId('lost_found_item_id')->constrained('lost_found_items')->cascadeOnDelete();
                $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->text('comment_text');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('lost_found_chat_threads')) {
            Schema::create('lost_found_chat_threads', function (Blueprint $table) {
                $table->id();
                $table->foreignId('lost_found_item_id')->constrained('lost_found_items')->cascadeOnDelete();
                $table->foreignId('publisher_id')->nullable()->constrained('users')->nullOnDelete();
                $table->foreignId('interested_user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('status', 30)->default('open');
                $table->timestamps();
                $table->unique(['lost_found_item_id', 'interested_user_id'], 'lf_thread_item_user_unique');
            });
        } elseif (! $this->hasIndex('lost_found_chat_threads', 'lf_thread_item_user_unique')) {
            Schema::table('lost_found_chat_threads', function (Blueprint $table) {
                $table->unique(['lost_found_item_id', 'interested_user_id'], 'lf_thread_item_user_unique');
            });
        }

        if (! Schema::hasTable('lost_found_chat_messages')) {
            Schema::create('lost_found_chat_messages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('lost_found_chat_thread_id')->constrained('lost_found_chat_threads')->cascadeOnDelete();
                $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();
                $table->text('message_text');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('lost_found_abuse_reports')) {
            Schema::create('lost_found_abuse_reports', function (Blueprint $table) {
                $table->id();
                $table->foreignId('reporter_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('reportable_type', 80);
                $table->unsignedBigInteger('reportable_id');
                $table->text('reason');
                $table->string('status', 30)->default('pending');
                $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('reviewed_at')->nullable();
                $table->timestamps();
                $table->index(['reportable_type', 'reportable_id'], 'lf_abuse_reportable_index');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('lost_found_abuse_reports');
        Schema::dropIfExists('lost_found_chat_messages');
        Schema::dropIfExists('lost_found_chat_threads');
        Schema::dropIfExists('lost_found_comments');
        Schema::dropIfExists('lost_found_items');
    }

    private function hasIndex(string $table, string $index): bool
    {
        return collect(DB::select("SHOW INDEX FROM {$table} WHERE Key_name = ?", [$index]))->isNotEmpty();
    }
};
