<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('report_id')->unique();
            $table->unsignedBigInteger('citizen_id');
            $table->tinyInteger('stars');
            $table->text('comment')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->foreign('report_id')->references('id')->on('reports')->onDelete('cascade');
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
        });
    }
    public function down(): void {
        Schema::dropIfExists('ratings');
    }
};