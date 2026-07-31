<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('permissions')->updateOrInsert(
            ['permission_name' => 'manage_initiatives'],
            ['description' => 'Manage community initiatives']
        );

        $permissionId = DB::table('permissions')->where('permission_name', 'manage_initiatives')->value('id');

        foreach (['admin', 'reception'] as $roleName) {
            $roleId = DB::table('roles')->where('role_name', $roleName)->value('id');

            if ($roleId && $permissionId) {
                DB::table('role_permissions')->updateOrInsert([
                    'role_id' => $roleId,
                    'permission_id' => $permissionId,
                ]);
            }
        }
    }

    public function down(): void
    {
        $permissionId = DB::table('permissions')->where('permission_name', 'manage_initiatives')->value('id');

        if ($permissionId) {
            DB::table('role_permissions')->where('permission_id', $permissionId)->delete();
            DB::table('permissions')->where('id', $permissionId)->delete();
        }
    }
};
