<?php include('includes/header.php'); ?>

<div class="container">
    <h2>Gestão de Simulações</h2>
    <div class="card sim-card">
        <div class="sim-details">
            <div class="sim-id">Simulação #123456</div>
            <div class="sim-meta">
                <span><strong>Criador:</strong> Maria</span> |
                <span><strong>Data:</strong> 05/05/2026</span>
            </div>

            <div class="sim-actions-container" style="margin-top: 15px;">
                <?php if (/* logica de dono */): ?>
                    <a href="configurar.php?id=123" class="edit-icon">
                        <i class="fas fa-pencil-alt"></i> Editar
                    </a>
                <?php else: ?>
                    <a href="detalhes_historico.php?id=123" class="btn-submit">
                        Ver detalhes
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <?php // } (fim do loop) ?>
</div>

<?php include('includes/footer.php'); ?>