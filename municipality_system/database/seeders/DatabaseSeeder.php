<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Department;
use App\Models\Area;
use App\Models\EmergencyContact;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $roles = [
            'citizen' => 'Mobile application user who can submit reports and suggestions.',
            'admin' => 'System administrator with full dashboard access.',
            'reception' => 'Reception dashboard account that reviews and assigns reports.',
            'department' => 'Unified dashboard account for a municipality department.',
        ];

        foreach ($roles as $name => $description) {
            Role::updateOrCreate(
                ['role_name' => $name],
                ['description' => $description]
            );
        }

        $permissions = [
            'manage_users',
            'manage_departments',
            'manage_categories',
            'manage_public_facilities',
            'manage_projects',
            'view_analytics',
            'review_reports',
            'assign_reports',
            'review_suggestions',
            'process_department_reports',
            'submit_reports',
            'submit_suggestions',
            'vote_suggestions',
            'rate_reports',
        ];

        foreach ($permissions as $permission) {
            Permission::updateOrCreate(
                ['permission_name' => $permission],
                ['description' => str_replace('_', ' ', ucfirst($permission))]
            );
        }

        Role::where('role_name', 'admin')->first()
            ?->permissions()
            ->sync(Permission::pluck('id')->all());

        Role::where('role_name', 'reception')->first()
            ?->permissions()
            ->sync(Permission::whereIn('permission_name', [
                'review_reports',
                'assign_reports',
                'review_suggestions',
            ])->pluck('id')->all());

        Role::where('role_name', 'department')->first()
            ?->permissions()
            ->sync(Permission::whereIn('permission_name', [
                'process_department_reports',
            ])->pluck('id')->all());

        Role::where('role_name', 'citizen')->first()
            ?->permissions()
            ->sync(Permission::whereIn('permission_name', [
                'submit_reports',
                'submit_suggestions',
                'vote_suggestions',
                'rate_reports',
            ])->pluck('id')->all());

        $departments = [
            'Roads Department' => [
                'Potholes',
                'Road damage',
                'Public infrastructure issue',
            ],
            'Lighting Department' => [
                'Broken streetlight',
            ],
            'Sanitation Department' => [
                'Garbage accumulation',
                'Fallen tree',
            ],
            'Sewage Department' => [
                'Sewage leak',
            ],
        ];

        foreach ($departments as $departmentName => $categories) {
            $department = Department::updateOrCreate(
                ['dept_name' => $departmentName],
                [
                    'description' => $departmentName,
                    'is_active' => true,
                ]
            );

            foreach ($categories as $categoryName) {
                Category::updateOrCreate(
                    ['category_name' => $categoryName],
                    [
                        'description' => $categoryName,
                        'dept_id' => $department->id,
                        'is_active' => true,
                    ]
                );
            }
        }

        $adminRole = Role::where('role_name', 'admin')->firstOrFail();
        $receptionRole = Role::where('role_name', 'reception')->firstOrFail();
        $departmentRole = Role::where('role_name', 'department')->firstOrFail();
        $citizenRole = Role::where('role_name', 'citizen')->firstOrFail();

        User::updateOrCreate(
            ['email' => 'admin@baladiyati.test'],
            [
                'full_name' => 'System Administrator',
                'phone' => '0910000001',
                'password' => Hash::make('password'),
                'is_active' => true,
                'role_id' => $adminRole->id,
                'dept_id' => null,
            ]
        );

        User::updateOrCreate(
            ['email' => 'reception@baladiyati.test'],
            [
                'full_name' => 'Reception Account',
                'phone' => '0910000002',
                'password' => Hash::make('password'),
                'is_active' => true,
                'role_id' => $receptionRole->id,
                'dept_id' => null,
            ]
        );

        User::updateOrCreate(
            ['email' => 'citizen@baladiyati.test'],
            [
                'full_name' => 'Demo Citizen',
                'phone' => '0910000003',
                'password' => Hash::make('password'),
                'is_active' => true,
                'role_id' => $citizenRole->id,
                'dept_id' => null,
            ]
        );

        foreach (Department::orderBy('id')->get() as $index => $department) {
            User::updateOrCreate(
                ['dept_id' => $department->id],
                [
                    'full_name' => $department->dept_name.' Account',
                    'email' => 'department'.$department->id.'@baladiyati.test',
                    'phone' => '092000000'.($index + 1),
                    'password' => Hash::make('password'),
                    'is_active' => true,
                    'role_id' => $departmentRole->id,
                    'dept_id' => $department->id,
                ]
            );
        }

        $areas = [
            ['area_name' => 'Tripoli Center', 'city' => 'Tripoli'],
            ['area_name' => 'Hay Al-Andalus', 'city' => 'Tripoli'],
            ['area_name' => 'Ain Zara', 'city' => 'Tripoli'],
        ];

        foreach ($areas as $area) {
            Area::updateOrCreate(
                ['area_name' => $area['area_name'], 'city' => $area['city']],
                ['boundary_coords' => null]
            );
        }

        EmergencyContact::updateOrCreate([
            'phone' => '1415',
        ], [
            'name' => 'Municipality Emergency Line',
            'alt_phone' => null,
            'category' => 'municipality',
            'description' => 'General municipality emergency contact.',
            'added_by' => User::where('email', 'admin@baladiyati.test')->value('id'),
            'is_active' => true,
        ]);
    }
}
