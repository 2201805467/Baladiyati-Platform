<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('public_facilities', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100);
            $table->string('facility_type', 50);
            $table->decimal('latitude', 10, 8);
            $table->decimal('longitude', 11, 8);
            $table->string('working_hours', 100)->nullable();
            $table->text('services')->nullable();
            $table->unsignedBigInteger('added_by');
            $table->boolean('is_active')->default(true);
            $table->foreign('added_by')->references('id')->on('users')->onDelete('cascade');
        });
    }
    public function down(): void {
        Schema::dropIfExists('public_facilities');
    }
};