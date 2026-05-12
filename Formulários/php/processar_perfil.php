<?php
// 1. Iniciar sessão apenas aqui
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// 2. Chamar o SPHandler
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Verificar se existe sessão ativa
    if (!isset($_SESSION['IDUtilizador'])) {
        header("Location: ../interface/index.php");
        exit();
    }

    $id_logado = $_SESSION['IDUtilizador'];
    
    // Montar o JSON com os dados vindos do formulário
    $json_envio = json_encode([
        "IDUtilizador" => (int)$id_logado,
        "Nome" => $_POST['nome'],
        "Email" => $_POST['email'],
        "Telemovel" => $_POST['telemovel'],
        "DataNascimento" => $_POST['data_nascimento']
    ]);

    try {
        // Executar a Stored Procedure
        $spManager->getData('SP_EditarPerfil', [$id_logado, $json_envio]);
        
        // Atualizar os dados da sessão para refletir no site imediatamente
        $_SESSION['user_email'] = $_POST['email'];
        $_SESSION['user_nome']  = $_POST['nome'];
        
        // Redirecionar para o perfil com sucesso
        header("Location: ../interface/perfil.php?msg=perfil_atualizado");
        exit();

    } catch (Exception $e) {
        // Em caso de erro (ex: email duplicado), volta para a edição com o erro
        $mensagem_erro = urlencode($e->getMessage());
        header("Location: ../interface/editar_perfil.php?erro=" . $mensagem_erro);
        exit();
    }
}
// Se tentarem aceder sem ser POST
header("Location: ../interface/index.php");
exit();