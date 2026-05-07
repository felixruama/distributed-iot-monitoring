<?php
session_start();
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Garante que o ID existe na sessão
    if (!isset($_SESSION['IDUtilizador'])) {
        header("Location: ../interface/index.php");
        exit();
    }

    $id_logado = $_SESSION['IDUtilizador']; // ID 21
    
    // Cria o array com os dados (AGORA COM O ID INCLUÍDO!)
    // Cria o array com os dados e transforma espaços vazios em NULL
    $dadosParaAtualizar = [
        "IDUtilizador" => $id_logado,
        "Nome" => $_POST['nome'],
        "Telemovel" => empty($_POST['telemovel']) ? null : $_POST['telemovel'],
        "DataNascimento" => empty($_POST['data_nascimento']) ? null : $_POST['data_nascimento']
    ];

    // Converte para JSON
    $json_string = json_encode($dadosParaAtualizar);

    try {
        // Chama a SP enviando o ID e o JSON
        $spManager->executeAction('SP_EditarPerfil', [$id_logado, $json_string]);
        
        header("Location: ../interface/perfil.php?msg=perfil_atualizado");
        exit();
    } catch (PDOException $e) {
        $erro = urlencode($e->getMessage());
        header("Location: ../interface/perfil.php?erro=$erro");
        exit();
    }
}
?>