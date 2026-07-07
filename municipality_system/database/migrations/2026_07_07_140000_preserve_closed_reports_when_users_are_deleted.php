<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropForeign(['citizen_id']);
            $table->unsignedBigInteger('citizen_id')->nullable()->change();
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('set null');
        });

        Schema::table('ratings', function (Blueprint $table) {
            $table->dropForeign(['citizen_id']);
            $table->unsignedBigInteger('citizen_id')->nullable()->change();
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('set null');
        });

        Schema::table('report_images', function (Blueprint $table) {
            $table->dropForeign(['uploaded_by']);
            $table->unsignedBigInteger('uploaded_by')->nullable()->change();
            $table->foreign('uploaded_by')->references('id')->on('users')->onDelete('set null');
        });

        Schema::table('report_logs', function (Blueprint $table) {
            $table->dropForeign(['action_by']);
            $table->unsignedBigInteger('action_by')->nullable()->change();
            $table->foreign('action_by')->references('id')->on('users')->onDelete('set null');
        });

        Schema::table('report_comments', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->unsignedBigInteger('user_id')->nullable()->change();
            $table->foreign('user_id')->references('id')->on('users')->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::table('report_comments', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->unsignedBigInteger('user_id')->nullable(false)->change();
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });

        Schema::table('report_logs', function (Blueprint $table) {
            $table->dropForeign(['action_by']);
            $table->unsignedBigInteger('action_by')->nullable(false)->change();
            $table->foreign('action_by')->references('id')->on('users')->onDelete('cascade');
        });

        Schema::table('report_images', function (Blueprint $table) {
            $table->dropForeign(['uploaded_by']);
            $table->unsignedBigInteger('uploaded_by')->nullable(false)->change();
            $table->foreign('uploaded_by')->references('id')->on('users')->onDelete('cascade');
        });

        Schema::table('ratings', function (Blueprint $table) {
            $table->dropForeign(['citizen_id']);
            $table->unsignedBigInteger('citizen_id')->nullable(false)->change();
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->dropForeign(['citizen_id']);
            $table->unsignedBigInteger('citizen_id')->nullable(false)->change();
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
        });
    }
};
