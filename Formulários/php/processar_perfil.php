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
        "Email" => $_POST['email'],
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
        // 1. Guardamos o erro feio do MySQL numa variável
        $erro_bruto = $e->getMessage();
        
        // 2. O nosso "Tradutor"
        if (strpos($erro_bruto, 'check_telemovel_formato') !== false) {
            // Se o erro tiver a ver com a nossa regra do telemóvel, pomos a mensagem bonita:
            $erro_amigavel = "O número de telemóvel tem de ter exatamente 9 dígitos numéricos.";
            
        } elseif (strpos($erro_bruto, 'Duplicate entry') !== false) {
            // Bónus: Se alguém tentar usar um email que já existe!
            $erro_amigavel = "Este email já se encontra registado no sistema.";
            
        } elseif (strpos($erro_bruto, 'SQLSTATE[45000]') !== false) {
            // Se for um dos nossos erros personalizados das Stored Procedures (SIGNAL)
            // O MySQL costuma enviá-los limpos depois do código 45000
            $partes = explode('Erro:', $erro_bruto);
            $erro_amigavel = isset($partes[1]) ? trim($partes[1]) : "Erro de validação nos dados.";
            
        } else {
            // Se for um erro que não conhecemos, mostramos uma mensagem genérica de segurança
            $erro_amigavel = "Ocorreu um erro ao processar o pedido. Tente novamente.";
        }

        // 3. Enviamos a mensagem bonita para o ecrã
        header("Location: ../interface/perfil.php?erro=" . urlencode($erro_amigavel));
        exit();
    }
}
?>