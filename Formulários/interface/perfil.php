<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

if (!isset($_SESSION['IDUtilizador'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

$id_logado = $_SESSION['IDUtilizador'];
$dados_perfil = [];

try {
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
        <p style="color: #888;">Consulta as tuas informações de conta e contacto</p>
        
        <?php if(isset($_GET['msg']) && $_GET['msg'] == 'perfil_atualizado'): ?>
            <div class="alert alert-success" style="color: green; font-weight: bold; margin-top: 10px;">
                <i class="fas fa-check-circle"></i> Perfil atualizado com sucesso!
            </div>
        <?php endif; ?>
    </div>

    <div class="card profile-card">
        <h2 style="font-size: 1.4rem; border-bottom: none; margin-bottom: 35px; color: #444;">
            <i class="fas fa-id-card" style="margin-right: 10px; color: var(--tech-blue);"></i>
            Dados do Utilizador
        </h2>

        <div class="profile-grid">
            <div class="form-group-alt full-width">
                <label>Nome Completo</label>
                <div class="input-pill readonly-field">
                    <input type="text" value="<?php echo htmlspecialchars($dados_perfil['Nome'] ?? 'Não definido'); ?>" readonly>
                    <i class="fas fa-user"></i>
                </div>
            </div>

            <div class="form-group-alt">
                <label>Telemóvel</label>
                <div class="input-pill readonly-field">
                    <input type="tel" value="<?php echo htmlspecialchars($dados_perfil['Telemovel'] ?? 'Não definido'); ?>" readonly>
                    <i class="fas fa-phone"></i>
                </div>
            </div>

            <div class="form-group-alt">
                <label>E-mail</label>
                <div class="input-pill readonly-field">
                    <input type="email" value="<?php echo htmlspecialchars($dados_perfil['Email'] ?? 'Não definido'); ?>" readonly>
                    <i class="fas fa-envelope"></i>
                </div>
            </div>

            <div class="form-group-alt">
                <label>Data de Nascimento</label>
                <div class="input-pill readonly-field">
                    <input type="date" value="<?php echo htmlspecialchars($dados_perfil['DataNascimento'] ?? ''); ?>" readonly>
                    <i class="fas fa-calendar-alt"></i>
                </div>
            </div>

            <div class="form-group-alt">
                <label>ID de Utilizador</label>
                <div class="input-pill readonly-field">
                    <input type="text" value="#<?php echo $dados_perfil['IDUtilizador']; ?>" readonly>
                    <i class="fas fa-lock"></i>
                </div>
            </div>
        </div>

        <div class="profile-actions">
            <a href="dashboard.php" class="nav-btn btn-secondary" style="padding: 12px 30px;">
                ← Voltar
            </a>
            <a href="editar_perfil.php" class="btn-submit" style="padding: 12px 40px; text-decoration: none;">
                <i class="fas fa-pencil-alt" style="margin-right: 8px;"></i> Editar Perfil
            </a>
        </div>
    </div>
</div>

<?php include('includes/footer.php'); ?>