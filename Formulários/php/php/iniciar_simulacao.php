<?php
session_start();
require_once('SPHandler.php');

$id_simulacao = $_GET['id'];

try {
    $spManager->executeAction('SP_IniciarSimulacao', [$id_simulacao]);
    header("Location: ../interface/dashboard.php?msg=simulacao_iniciada");
} catch (PDOException $e) {
    header("Location: ../interface/dashboard.php?erro=falha_iniciar");
}
exit();
?>