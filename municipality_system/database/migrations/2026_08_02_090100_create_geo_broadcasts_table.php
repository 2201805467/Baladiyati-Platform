<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('geo_broadcasts', function (Blueprint $table) {
            $table->id();
            $table->string('title', 200);
            $table->text('body');
            $table->string('broadcast_type', 30);
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->unsignedInteger('radius_meters')->default(500);
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->string('status', 30)->default('active');
            $table->text('cancel_reason')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('geo_broadcast_recipients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('geo_broadcast_id')->constrained('geo_broadcasts')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('matched_by', 30);
            $table->foreignId('notification_id')->nullable()->constrained('notifications')->nullOnDelete();
            $table->timestamps();
            $table->unique(['geo_broadcast_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('geo_broadcast_recipients');
        Schema::dropIfExists('geo_broadcasts');
    }
};
