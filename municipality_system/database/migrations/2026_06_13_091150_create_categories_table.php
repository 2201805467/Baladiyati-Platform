<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('category_name', 100)->unique();
            $table->text('description')->nullable();
            $table->unsignedBigInteger('dept_id');
            $table->boolean('is_active')->default(true);
            $table->foreign('dept_id')->references('id')->on('departments')->onDelete('cascade');
        });
    }
    public function down(): void {
        Schema::dropIfExists('categories');
    }
};