<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('initiative_registrations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('initiative_id');
            $table->unsignedBigInteger('citizen_id')->nullable();
            $table->string('status', 50)->default('registered');
            $table->timestamp('registered_at')->useCurrent();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('attended_at')->nullable();
            $table->decimal('attendance_latitude', 10, 8)->nullable();
            $table->decimal('attendance_longitude', 11, 8)->nullable();
            $table->timestamps();

            $table->unique(['initiative_id', 'citizen_id']);
            $table->foreign('initiative_id')->references('id')->on('community_initiatives')->onDelete('cascade');
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('initiative_registrations');
    }
};
