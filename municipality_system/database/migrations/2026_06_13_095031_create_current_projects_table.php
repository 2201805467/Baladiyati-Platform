<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('current_projects', function (Blueprint $table) {
            $table->id();
            $table->string('name', 200);
            $table->text('description')->nullable();
            $table->unsignedBigInteger('area_id')->nullable();
            $table->string('contractor', 100)->nullable();
            $table->tinyInteger('progress_percent')->default(0);
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->unsignedBigInteger('added_by')->nullable();
            $table->string('status', 50)->default('planned');
            $table->foreign('area_id')->references('id')->on('areas')->onDelete('set null');
            $table->foreign('added_by')->references('id')->on('users')->onDelete('set null');
        });
    }
    public function down(): void {
        Schema::dropIfExists('current_projects');
    }
};
