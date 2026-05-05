<?php include('includes/header.php'); ?>

<div class="container">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px;">
        <h1>Gestão de Simulações</h1>

        <!-- Botões lado a lado -->
        <div class="dashboard-actions">
            <a href="configurar.php" class="nav-btn">Criar Simulação</a>
            <a href="historico.php" class="nav-btn" style="background-color: #666;">Ver Histórico</a>
        </div>
    </div>

    <p style="color: #666; margin-bottom: 20px;">Simulações ativas ou prontas a iniciar (Estados 0 e 1):</p>

    <!-- Exemplo: Simulação do Dono -->
    <div class="card sim-card">
        <div class="info">
            <div style="font-size: 1.1rem; font-weight: bold;">Simulação #123456</div>
            <div style="color: #666; font-size: 0.9rem;">Criador: Maria | Estado: <span style="color: orange; font-weight: bold;">Criada</span></div>
        </div>
        <div class="actions" style="display: flex; align-items: center; gap: 20px;">
            <button class="btn-submit" style="background-color: #28a745;">Iniciar Simulação</button>
            <a href="configurar.php?id=123456" class="edit-icon" title="Editar">
                <i class="fas fa-pencil-alt"></i>
            </a>
        </div>
    </div>

    <!-- Exemplo: Simulação de Outro -->
    <div class="card sim-card">
        <div class="info">
            <div style="font-size: 1.1rem; font-weight: bold;">Simulação #123457</div>
            <div style="color: #666; font-size: 0.9rem;">Criador: João | Estado: <span style="color: blue; font-weight: bold;">Iniciada</span></div>
        </div>
        <div class="actions">
            <a href="detalhes_simulacao.php?id=123457" class="btn-submit">Ver detalhes</a>
        </div>
    </div>

</div>

<?php include('includes/footer.php'); ?>