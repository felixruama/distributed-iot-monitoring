<?php
session_start();
require_once('SPHandler.php');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    try {
        // 1. Validação de Credenciais (Nível MySQL)
        // Tenta ligar ao MySQL. Se falhar, a password está errada.
        $teste_ligacao = new PDO("mysql:host=mysql;dbname=labirinto_DB;charset=utf8mb4", $email, $password);
        $teste_ligacao->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $teste_ligacao = null; 

        // 2. Obter dados do perfil
        $resultado = $spManager->getData('SP_ValidarLogin', [$email]);
        $user = $resultado[0] ?? null;

        if ($user) {
            // ============================================================
            // 3. REGRA DE OURO: FILTRO DE TIPO DE UTILIZADOR
            // ============================================================
            if ($user['Tipo'] !== 'Utilizador') {
                // Se não for "Utilizador", barramos a entrada na Web
                header("Location: ../interface/index.php?erro=" . urlencode("Acesso negado: Esta plataforma é exclusiva para utilizadores comuns."));
                exit();
            }

            if ($user['Equipa'] != 7) {
                header("Location: ../interface/index.php?erro=" . urlencode("Acesso negado: Apenas os membros da Equipa 7 podem entrar neste site."));
                exit();
            }

            // Se chegou aqui, é porque é 'Utilizador'. Criamos a sessão.
            $_SESSION['IDUtilizador'] = $user['IDUtilizador'];
            $_SESSION['user_nome']    = $user['Nome'];
            $_SESSION['user_email']   = $user['Email'];
            $_SESSION['user_tipo']    = $user['Tipo']; 
            $_SESSION['user_equipa']  = $user['Equipa'];

            header("Location: ../interface/dashboard.php");
            exit();
        } else {
            header("Location: ../interface/index.php?erro=" . urlencode("Utilizador não encontrado no sistema."));
            exit();
        }

    } catch (PDOException $e) {
        header("Location: ../interface/index.php?erro=" . urlencode("Email ou Password incorretos."));
        exit();
    } catch (Exception $e) {
        header("Location: ../interface/index.php?erro=" . urlencode("Erro no servidor."));
        exit();
    }
}