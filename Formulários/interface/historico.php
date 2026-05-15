<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Proteção: apenas utilizadores logados
if (!isset($_SESSION['user_email'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

// Chamada à nova SP de Histórico
$historico = $spManager->getData('SP_ObterHistorico', []);

include('includes/header.php'); 
?>

<div class="container">
    <div style="margin-bottom: 30px;">
        <a href="dashboard.php" class="btn-back" style="text-decoration: none; color: var(--tech-blue); font-weight: bold;">
            ← Voltar ao Dashboard
        </a>
        <h1 style="margin-top: 20px;">Arquivo de Simulações</h1>
        <p style="color: #666;">Consulta aqui o registo de todas as simulações terminadas (Estado: Terminada).</p>
    </div>

    <?php if (empty($historico)): ?>
        <div class="card" style="text-align: center; padding: 40px;">
            <p style="color: #888;">O arquivo está vazio. As simulações aparecerão aqui assim que forem terminadas.</p>
        </div>
    <?php else: ?>
     <?php foreach ($historico as $registo): ?>
    <div class="card sim-card">
        <div class="sim-details">
            <div class="sim-id" style="font-size: 1.2rem; font-weight: bold;">
                Simulação #<?php echo $registo['IDSimulacao']; ?>
                <span style="font-size: 0.9rem; font-weight: normal; color: #777;">
                    - <?php echo htmlspecialchars($registo['Descricao']); ?>
                </span>
            </div>
            <div class="sim-meta" style="margin: 8px 0; color: #666; font-size: 0.9rem;">
                <span><strong>Criador:</strong> <?php echo htmlspecialchars($registo['NomeCriador'] ?? 'Desconhecido'); ?></span> |
                <span><strong>Início:</strong> <?php echo $registo['DataHoraInicio'] ?? '---'; ?></span>
                <span style="color: #b30000;"><strong>Motivo:</strong> <?php echo htmlspecialchars($registo['motivo_fim'] ?? 'Desconhecido'); ?></span>
            </div>
            <span class="badge" style="background-color: #d4edda; color: #155724; padding: 4px 10px; border-radius: 10px; font-size: 0.8rem;">
                Estado: Terminada
            </span>
        </div>
        <div class="sim-actions">
            <a href="detalhes_historico.php?id=<?php echo $registo['IDSimulacao']; ?>" class="nav-btn">Ver detalhes</a>
        </div>
    </div>
<?php endforeach; ?>
    <?php endif; ?>

</div>

<?php include('includes/footer.php'); ?>