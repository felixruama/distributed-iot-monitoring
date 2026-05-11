<?php
session_start();
require_once('SPHandler.php');

$id_simulacao = $_GET['id'];

try {
    // Script Python
    $python_path = realpath(__DIR__ . '/../../ScriptsPython/MySQL(PC2)/cloudToMySQL.py');
    $comando_python = "python " . escapeshellarg($python_path);
    //espera acabar
    exec($comando_python, $output_py, $status_py);
    $spManager->executeAction('SP_IniciarSimulacao', [$id_simulacao]);
    // mazerun.exe
    $mazerun_path = realpath(__DIR__ . '/../../Mazerun/mazerun.exe');
    //abre o Mazerun.exe em segundo plano 
    if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
        pclose(popen("start \"\" " . escapeshellarg($mazerun_path), "r"));
    }
    header("Location: ../interface/dashboard.php?msg=simulacao_iniciada");
} catch (Exception $e) {
    header("Location: ../interface/dashboard.php?erro=falha_iniciar");
}
exit();
?>
