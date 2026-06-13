<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->string('report_number', 20)->unique();
            $table->unsignedBigInteger('citizen_id');
            $table->unsignedBigInteger('category_id')->nullable();
            $table->unsignedBigInteger('dept_id')->nullable();
            $table->unsignedBigInteger('area_id')->nullable();
            $table->text('description')->nullable();
            $table->decimal('latitude', 10, 8);
            $table->decimal('longitude', 11, 8);
            $table->string('severity', 50)->default('medium');
            $table->string('status', 50)->default('new');
            $table->string('ai_suggested_category', 100)->nullable();
            $table->boolean('is_duplicate')->default(false);
            $table->unsignedBigInteger('parent_report_id')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('category_id')->references('id')->on('categories')->onDelete('set null');
            $table->foreign('dept_id')->references('id')->on('departments')->onDelete('set null');
            $table->foreign('area_id')->references('id')->on('areas')->onDelete('set null');
            $table->foreign('parent_report_id')->references('id')->on('reports')->onDelete('set null');
        });
    }
    public function down(): void {
        Schema::dropIfExists('reports');
    }
};