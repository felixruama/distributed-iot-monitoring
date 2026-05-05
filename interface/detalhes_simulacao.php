<?php include('includes/header.php'); ?>

<div class="page-header">
    <a href="dashboard.php" class="btn-back">← Voltar</a>
    <h2>Detalhes da Simulação (Consulta)</h2>
</div>

<!-- Secção de Info Geral (ID, Criador, Estado) -->
<section class="card card-read-only">
    <div class="info-grid">
        <p><strong>ID:</strong> 123456</p>
        <p><strong>Estado:</strong> Criada</p>
        <p><strong>Criador:</strong> Maria</p>
    </div>
</section>

<!-- Secção de Parâmetros de Controlo -->
<section class="card">
    <h3>Parâmetros de Controlo</h3>
    <div class="params-display">
        <div class="param-row">
            <span>Temperaturas Críticas:</span>
            <span>Mín: 15°C / Máx: 50°C</span>
        </div>
        <div class="param-row">
            <span>Ruído Crítico:</span>
            <span>70 dB</span>
        </div>
        <div class="param-row">
            <span>Periodicidade de Leitura:</span>
            <span>2 s</span>
        </div>
        <div class="param-row">
            <span>Intervalo entre Alertas:</span>
            <span>2 s</span>
        </div>
        <div class="param-row">
            <span>Margem de erro:</span>
            <span>5</span>
        </div>
    </div>
    <p class="note">Modo de visualização passiva. Apenas o criador pode editar estes valores.</p>
</section>

<?php include('includes/footer.php'); ?>