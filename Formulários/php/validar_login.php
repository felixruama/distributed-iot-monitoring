<?php
session_start();
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    try {
        // A SP faz a dupla verificação (Credenciais + Tipo)
        $resultado = $spManager->getData('SP_ValidarLogin', [$email, $password]);
        $user = $resultado[0] ?? null;

        if ($user) {
            // Sucesso absoluto!
            $_SESSION['IDUtilizador'] = $user['IDUtilizador'];
            $_SESSION['user_nome']    = $user['Nome'];
            $_SESSION['user_email']   = $user['Email'];
            $_SESSION['user_tipo']    = $user['Tipo']; 
            $_SESSION['user_equipa']  = $user['Equipa'];

            header("Location: ../interface/dashboard.php");
            exit();
            
        } else {
            // A SP não devolveu nada. Mensagem única e segura:
            header("Location: ../interface/index.php?erro=" . urlencode("Email/Password incorretos ou acesso não autorizado para este tipo de conta."));
            exit();
        }

    } catch (Exception $e) {
        header("Location: ../interface/index.php?erro=" . urlencode("Erro no servidor: " . $e->getMessage()));
        exit();
    }
}