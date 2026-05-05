<?php include('includes/header.php'); ?>

<div class="container">
    <div style="margin-bottom: 30px;">
        <a href="dashboard.php" class="btn-back">← Voltar ao Dashboard</a>
        <h1>Arquivo de Simulações</h1>
        <p style="color: #666;">Consulta aqui o registo de todas as simulações terminadas.</p>
    </div>

    <!-- Exemplo de Simulação no Histórico (Repetir este bloco para cada registo) -->
    <div class="card sim-card">
        <div class="sim-details">
            <div class="sim-id">Simulação #123456</div>
            <div class="sim-meta">
                <span><strong>Criador:</strong> Maria</span> |
                <span><strong>Data:</strong> 05/05/2026</span>
            </div>
            <span class="badge badge-finished">Estado: Terminada</span>
        </div>
        <div class="sim-actions">
            <a href="detalhes_historico.php?id=123456" class="nav-btn">Ver detalhes</a>
        </div>
    </div>

    <!-- Outro exemplo -->
    <div class="card sim-card">
        <div class="sim-details">
            <div class="sim-id">Simulação #123455</div>
            <div class="sim-meta">
                <span><strong>Criador:</strong> João</span> |
                <span><strong>Data:</strong> 04/05/2026</span>
            </div>
            <span class="badge badge-finished">Estado: Terminada</span>
        </div>
        <div class="sim-actions">
            <a href="detalhes_historico.php?id=123455" class="nav-btn">Ver detalhes</a>
        </div>
    </div>

</div>

<?php include('includes/footer.php'); ?>