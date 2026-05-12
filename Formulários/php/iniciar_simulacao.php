<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
require_once('SPHandler.php');

$id_simulacao = $_GET['id'] ?? null;

if ($id_simulacao) {
    try {
        $spManager->executeAction('SP_IniciarSimulacao', [(int)$id_simulacao]);
        header("Location: ../interface/dashboard.php?msg=simulacao_iniciada");
    } catch (Exception $e) {
        $erro_bruto = $e->getMessage();
        $erro_limpo = preg_replace('/SQLSTATE\[\d+\]:.*?:\s*\d+\s*/', '', $erro_bruto);
        $mensagem_erro = urlencode($erro_limpo);
        header("Location: ../interface/dashboard.php?erro=" . $mensagem_erro);
    }
} else {
    header("Location: ../interface/dashboard.php?erro=ID+de+simulacao+invalido");
}
exit();
?>
