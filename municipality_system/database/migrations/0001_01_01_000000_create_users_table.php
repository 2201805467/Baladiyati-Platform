<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('full_name', 100);
            $table->string('email', 100)->unique();
            $table->string('phone', 20)->unique();
            $table->string('password', 255);
            $table->string('profile_image', 255)->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedBigInteger('role_id');
            $table->unsignedBigInteger('dept_id')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->nullable();
            $table->foreign('role_id')->references('id')->on('roles')->onDelete('restrict');
            $table->foreign('dept_id')->references('id')->on('departments')->onDelete('set null');
        });
    }
    public function down(): void {
        Schema::dropIfExists('users');
    }
};