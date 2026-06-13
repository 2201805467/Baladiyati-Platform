<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100);
            $table->string('phone', 20);
            $table->string('alt_phone', 20)->nullable();
            $table->string('category', 50);
            $table->text('description')->nullable();
            $table->unsignedBigInteger('added_by');
            $table->boolean('is_active')->default(true);
            $table->foreign('added_by')->references('id')->on('users')->onDelete('cascade');
        });
    }
    public function down(): void {
        Schema::dropIfExists('emergency_contacts');
    }
};