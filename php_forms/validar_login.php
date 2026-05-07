<?php
session_start();
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    try {
        // Chama a SP no MySQL
        $resultados = $spManager->getData('SP_ValidarLogin', [$email, $password]);
        
        if (!empty($resultados)) {
                        // Login com sucesso! Guardamos os dados REAIS na sessão
                    // ... dentro do if (!empty($resultados)) ...
            $_SESSION['user_email'] = $resultados[0]['Email'];
            $_SESSION['equipa'] = $resultados[0]['Equipa'];

            // Agora o PHP já consegue ler o ID 21 que a SP envia!
            $_SESSION['IDUtilizador'] = $resultados[0]['IDUtilizador'];

            header("Location: ../interface/dashboard.php?msg=login_sucesso");
            exit();
        } else {
            // Se a SP devolver vazio (Login errado)
            header("Location: ../interface/index.php?erro=credenciais_invalidas");
            exit();
        }
    } catch (PDOException $e) {
        // Se a SP deitar um erro (SIGNAL SQLSTATE)
        header("Location: ../interface/index.php?erro=credenciais_invalidas");
        exit();
    }
}
?>