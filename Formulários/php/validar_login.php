<?php
session_start();
require_once('SPHandler.php');
include "../App/Php/db_config.php";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    try {
        // 1. Validação de Credenciais no MySQL (Nível Motor)
        // MUDANÇA: Nome da BD corrigido para labirinto_DB_ruama
        $teste_ligacao = new PDO("mysql:host=mysql;dbname=labirinto_DB;charset=utf8mb4", $email, $password);
        $teste_ligacao->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $teste_ligacao = null;

        // 2. Obter dados do perfil do utilizador
        $resultado = $spManager->getData('SP_ValidarACESSO', [$email]);
        $user = $resultado[0] ?? null;

        if ($user) {
            // MUDANÇA: Redirecionamento corrigido para a pasta WebSite
            if ($user['Tipo'] !== 'Utilizador') {
                header("Location: ../WebSite/index.php?erro=" . urlencode("Acesso negado: Use a App ou Portal Admin."));
                exit();
            }

            $_SESSION['IDUtilizador'] = $user['IDUtilizador'];
            $_SESSION['user_nome']    = $user['Nome'];
            $_SESSION['user_email']   = $user['Email'];
            $_SESSION['user_tipo']    = $user['Tipo'];

            header("Location: ../WebSite/dashboard.php");
            exit();
        } else {
            header("Location: ../WebSite/index.php?erro=" . urlencode("Utilizador não encontrado."));
            exit();
        }

    } catch (PDOException $e) {
        header("Location: ../WebSite/index.php?erro=" . urlencode("Email ou Password incorretos."));
        exit();
    }
}
?>
