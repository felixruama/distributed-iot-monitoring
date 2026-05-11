<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Verifica se o utilizador está logado e se o ID está na sessão
if (!isset($_SESSION['IDUtilizador'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

$id_logado = $_SESSION['IDUtilizador'];
$dados_perfil = [];

try {
    // Vamos buscar os teus dados reais à base de dados
    $resultados = $spManager->getData('SP_ObterPerfil', [$id_logado]);
    
    if (!empty($resultados)) {
        $dados_perfil = $resultados[0];
    } else {
        die("Erro crítico: Conta não encontrada na Base de Dados.");
    }
} catch (PDOException $e) {
    die("Erro ao carregar o perfil: " . $e->getMessage());
}

include('includes/header.php'); 
?>

<div class="container">
    <div style="text-align: center; margin-bottom: 40px;">
        <h1 style="font-size: 2.2rem;">O meu Perfil</h1>
        <p style="color: #888;">Gere as tuas informações de conta e contacto</p>
        
        <?php if(isset($_GET['msg']) && $_GET['msg'] == 'perfil_atualizado'): ?>
            <p style="color: green; font-weight: bold; margin-top: 10px;">Perfil atualizado com sucesso!</p>
        <?php endif; ?>
        <?php if(isset($_GET['erro'])): ?>
            <p style="color: red; font-weight: bold; margin-top: 10px;">Erro: <?php echo htmlspecialchars(urldecode($_GET['erro'])); ?></p>
        <?php endif; ?>
    </div>

    <div class="card profile-card">
        <form action="../php/processar_perfil.php" method="POST">

            <h2 style="font-size: 1.4rem; border-bottom: none; margin-bottom: 35px; color: #444;">
                <i class="fas fa-id-card" style="margin-right: 10px; color: var(--tech-blue);"></i>
                Dados do Utilizador
            </h2>

            <div class="profile-grid">
                <div class="form-group-alt full-width">
                    <label>Nome Completo</label>
                    <div class="input-pill">
                        <input type="text" name="nome" value="<?php echo htmlspecialchars($dados_perfil['Nome'] ?? ''); ?>" required>
                        <i class="fas fa-user"></i>
                    </div>
                </div>

                <div class="form-group-alt">
                    <label>Telemóvel</label>
                    <div class="input-pill">
                        <input type="tel" name="telemovel" value="<?php echo htmlspecialchars($dados_perfil['Telemovel'] ?? ''); ?>">
                        <i class="fas fa-phone"></i>
                    </div>
                </div>

                <div class="form-group-alt">
                    <label>E-mail</label>
                    <div class="input-pill" style="background-color: #f9f9f9;">
                        <input type="email" name="email" value="<?php echo htmlspecialchars($dados_perfil['Email'] ?? ''); ?>" readonly>
                        <i class="fas fa-envelope"></i>
                    </div>
                </div>

                <div class="form-group-alt">
                    <label>Data de Nascimento</label>
                    <div class="input-pill">
                        <input type="date" name="data_nascimento" value="<?php echo htmlspecialchars($dados_perfil['DataNascimento'] ?? ''); ?>">
                        <i class="fas fa-calendar-alt"></i>
                    </div>
                </div>

                <div class="form-group-alt">
                    <label>ID de Utilizador (Apenas Leitura)</label>
                    <div class="input-pill" style="background-color: #f9f9f9; opacity: 0.7;">
                        <input type="text" value="#<?php echo $dados_perfil['IDUtilizador']; ?>" readonly>
                        <i class="fas fa-lock"></i>
                    </div>
                </div>
            </div>

            <div class="profile-actions">
                <a href="dashboard.php" class="nav-btn btn-secondary" style="padding: 12px 30px;">
                    Cancelar
                </a>
                <button type="submit" class="btn-submit btn-profile-save">
                    Atualizar Perfil
                </button>
            </div>
        </form>
    </div>
</div>

<?php include('includes/footer.php'); ?>