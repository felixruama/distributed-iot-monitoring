<?php
die("<h1>PARA TUDO! O DOCKER ESTA A LER O FICHEIRO CERTO!</h1>");
session_start();
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $id_logado = $_SESSION['IDUtilizador'];
    $nome      = $_POST['nome'];
    $email     = $_POST['email'];
    $telem     = $_POST['telemovel'];
    $data_n    = $_POST['data_nascimento'];

    // Monta o JSON para a Stored Procedure
    $dados_perfil = [
        "IDUtilizador"   => (int)$id_logado,
        "Nome"           => $nome,
        "Email"          => $email,
        "Telemovel"      => $telem,
        "DataNascimento" => $data_n
    ];

    $json_envio = json_encode($dados_perfil);

    try {
        $spManager->getData('SP_EditarPerfil', [$id_logado, $json_envio]);

        // Atualiza a sessão
        $_SESSION['user_email'] = $email;
        $_SESSION['user_nome']  = $nome;

        header("Location: ../interface/perfil.php?msg=perfil_atualizado");
        exit();

    } catch (Exception $e) {
        // MODO DETETIVE: Isto vai parar a página e mostrar o erro cru e real do MySQL!
        echo "<div style='background: #fee2e2; color: #991b1b; padding: 20px; font-size: 18px; border: 2px solid red;'>";
        echo "<h1>🚨 O ERRO REAL DO MYSQL É ESTE:</h1>";
        echo $e->getMessage();
        echo "</div>";
        exit();
    }
}
?>