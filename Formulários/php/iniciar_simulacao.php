<?php
#pip install pymongo mysql-connector-python paho-mqtt python-dotenv

session_start();
require_once('SPHandler.php');

if (!isset($_GET['id']) || !is_numeric($_GET['id'])) {
    header("Location: ../interface/dashboard.php?erro=id_invalido");
    exit();
}

$id_simulacao = (int)$_GET['id'];

try {
    $python_path = realpath(__DIR__ . '/../../ScriptsPython/MySQL(PC2)/cloudToMySQL.py');
    if ($python_path && file_exists($python_path)) {
        $comando_python = "python3 " . escapeshellarg($python_path);
        exec($comando_python, $output_py, $status_py);
    } else {
        throw new Exception("Ficheiro Python não encontrado pelo PHP.");
    }
    $spManager->executeAction('SP_IniciarSimulacao', [$id_simulacao]);
    header("Location: ../interface/dashboard.php?msg=simulacao_iniciada");

} catch (Exception $e) {
    header("Location: ../interface/dashboard.php?erro=falha_iniciar");
}
exit();
?>