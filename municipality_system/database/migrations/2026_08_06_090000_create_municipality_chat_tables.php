<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('municipality_chat_threads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('citizen_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->foreignId('assigned_dept_id')->nullable()->constrained('departments')->nullOnDelete();
            $table->string('status', 30)->default('new');
            $table->timestamp('last_message_at')->nullable();
            $table->unsignedInteger('citizen_unread_count')->default(0);
            $table->unsignedInteger('reception_unread_count')->default(0);
            $table->unsignedInteger('department_unread_count')->default(0);
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('municipality_chat_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('thread_id')->constrained('municipality_chat_threads')->cascadeOnDelete();
            $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('sender_role', 30);
            $table->text('message_text')->nullable();
            $table->string('image_url')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_system')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('municipality_chat_messages');
        Schema::dropIfExists('municipality_chat_threads');
    }
};
