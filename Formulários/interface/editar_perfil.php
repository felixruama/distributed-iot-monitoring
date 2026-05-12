<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
if (!isset($_SESSION['IDUtilizador'])) { header("Location: index.php"); exit(); }
require_once('../php/SPHandler.php');

$id_logado = $_SESSION['IDUtilizador'];
$dados_perfil = [];

try {
    $resultados = $spManager->getData('SP_ObterPerfil', [$id_logado]);
    if (!empty($resultados)) { $dados_perfil = $resultados[0]; } else { die("Erro crítico: Conta não encontrada."); }
} catch (PDOException $e) { die("Erro ao carregar o perfil: " . $e->getMessage()); }

include('includes/header.php');
?>

<div class="container">
    <div style="text-align: center; margin-bottom: 40px;">
        <h1 style="font-size: 2.2rem;">Editar Perfil</h1>
        <p style="color: #888;">Altere os dados abaixo e guarde as alterações.</p>
        <?php if(isset($_GET['erro'])): ?>
            <p style="color: red; font-weight: bold; margin-top: 10px;">Erro: <?php echo htmlspecialchars(urldecode($_GET['erro'])); ?></p>
        <?php endif; ?>
    </div>

    <div class="card profile-card" style="border-top: 5px solid var(--tech-blue);">
        <form action="../php/processar_perfil.php" method="POST">
            <h2 style="font-size: 1.4rem; border-bottom: none; margin-bottom: 35px; color: #444;">
                <i class="fas fa-user-edit" style="margin-right: 10px; color: var(--tech-blue);"></i> Modo de Edição
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
                    <label>E-mail (Login de Acesso)</label>
                    <div class="input-pill">
                        <input type="email" name="email" value="<?php echo htmlspecialchars($dados_perfil['Email'] ?? ''); ?>" required>
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
            </div>

            <div class="profile-actions">
                <a href="perfil.php" class="nav-btn btn-secondary" style="padding: 12px 30px;">Cancelar</a>
                <button type="submit" class="btn-submit btn-profile-save" style="background-color: #28a745;">
                    <i class="fas fa-save" style="margin-right: 8px;"></i> Guardar Alterações
                </button>
            </div>
        </form>
    </div>
</div>
<?php include('includes/footer.php'); ?>