<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_initiatives', function (Blueprint $table) {
            $table->id();
            $table->string('title', 200);
            $table->text('description');
            $table->text('goal')->nullable();
            $table->string('initiative_type', 50);
            $table->string('cover_image_url')->nullable();
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->decimal('latitude', 10, 8);
            $table->decimal('longitude', 11, 8);
            $table->unsignedInteger('radius_meters')->default(100);
            $table->unsignedInteger('max_capacity')->nullable();
            $table->string('target_audience', 100)->nullable();
            $table->text('requirements')->nullable();
            $table->string('status', 50)->default('published');
            $table->text('cancel_reason')->nullable();
            $table->string('completion_image_url')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamp('capacity_notified_at')->nullable();
            $table->timestamps();

            $table->foreign('created_by')->references('id')->on('users')->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_initiatives');
    }
};
