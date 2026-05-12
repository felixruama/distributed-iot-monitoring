<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $id_simulacao = $_POST['id_simulacao'];
    $id_utilizador = $_SESSION['IDUtilizador'];

    $params = [
        (int)$id_simulacao,
        (int)$id_utilizador,
        (float)$_POST['temp_max'],
        (float)$_POST['temp_min'],
        (float)$_POST['ruido_max'],
        (int)$_POST['periodicidade'],
        (int)$_POST['intervalo']
    ];

    try {
        $spManager->executeAction('SP_ValidarParametros', $params);

        // Sucesso: Volta para os detalhes
        header("Location: ../interface/detalhes_simulacao.php?id=$id_simulacao&msg=config_ok");
        exit();
    } catch (Exception $e) {
        // Se a SP disparar o SIGNAL de erro (ex: TempMin > TempMax)
        $erro = urlencode($e->getMessage());
        header("Location: ../interface/configuracao_simulacao.php?id=$id_simulacao&erro=$erro");
        exit();
    }
}