<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});

Auth::routes();

Route::get('/home', [App\Http\Controllers\HomeController::class, 'index'])->name('home');

Route::get('/debug-app-key', function () {
    return response()->json([
        'env_exists' => !empty(getenv('APP_KEY')),
        'config_exists' => !empty(config('app.key')),
        'env_length' => strlen((string) getenv('APP_KEY')),
        'config_length' => strlen((string) config('app.key')),
    ]);
});
