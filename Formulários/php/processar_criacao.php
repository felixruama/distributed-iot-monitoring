<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (!isset($_SESSION['IDUtilizador'])) {
        header("Location: ../interface/index.php"); exit();
    }

    $params = [
        $_SESSION['IDUtilizador'],
        $_POST['descricao'],
        (int)$_POST['temp_max'],
        (int)$_POST['temp_min'],
        (int)$_POST['ruido_max'],
        (int)$_POST['periodicidade'],
        (int)$_POST['intervalo']
    ];

    try {
        $resultado = $spManager->getData('SP_CriarSimulacao', $params);
        $novoID = $resultado[0]['IDSimulacao'];

        // Como já definimos tudo, vamos logo para os Detalhes da Simulação
        header("Location: ../interface/detalhes_simulacao.php?id=" . $novoID);
        exit();
    } catch (Exception $e) {
        header("Location: ../interface/dashboard.php?erro=" . urlencode($e->getMessage()));
        exit();
    }
}