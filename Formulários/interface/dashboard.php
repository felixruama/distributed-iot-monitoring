<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Verifica se o utilizador está logado, senão expulsa-o para o index
if (!isset($_SESSION['user_email'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

// Obter as simulações ativas através da nossa nova SP
$simulacoes = $spManager->getData('SP_ObterSimulacoesAtivas', []);

// O ID do utilizador logado para sabermos se ele é o "Dono" da simulação
$id_logado = $_SESSION['IDUtilizador'] ?? 0;
$equipa_logado = $_SESSION['user_equipa'] ?? -1;

include('includes/header.php'); 
?>

<div class="container">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px;">
        <h1>Gestão de Simulações</h1>

        <div class="dashboard-actions">
            <a href="criar_simulacao.php" class="nav-btn">Criar Simulação</a>
            <a href="historico.php" class="nav-btn" style="background-color: #666;">Ver Histórico</a>
        </div>
    </div>

    <p style="color: #666; margin-bottom: 20px;">Simulações ativas ou prontas a iniciar (Estados 0 e 1):</p>

    <?php if (empty($simulacoes)): ?>
        <div class="card">
            <p style="text-align: center; color: #888;">Não existem simulações ativas de momento. Cria uma nova!</p>
        </div>
    <?php else: ?>
        <?php foreach ($simulacoes as $sim): ?>
            <?php
                // Variáveis de controlo
                $is_criador = ($sim['Criador'] == $id_logado);
                $is_mesma_equipa = (isset($sim['Equipa']) && $sim['Equipa'] == $equipa_logado);

                $estado_texto = ($sim['Estado'] == '0') ? 'Criada' : 'Iniciada';
                $estado_cor = ($sim['Estado'] == '0') ? 'orange' : 'blue';
                $nome_criador = htmlspecialchars($sim['NomeCriador'] ?? 'Desconhecido');
            ?>
            <div class="card sim-card">
                <div class="info">
                    <div style="font-size: 1.1rem; font-weight: bold;">
                        Simulação #<?php echo $sim['IDSimulacao']; ?>
                        <span style="font-size: 0.9rem; font-weight: normal; color: #555;">(<?php echo htmlspecialchars($sim['Descricao'] ?? ''); ?>)</span>
                    </div>
                    <div style="color: #666; font-size: 0.9rem;">
                        Criador: <?php echo $nome_criador; ?> |
                        Estado: <span style="color: <?php echo $estado_cor; ?>; font-weight: bold;"><?php echo $estado_texto; ?></span>
                    </div>
                </div>

                <div class="actions" style="display: flex; align-items: center; gap: 20px;">
                    <?php if ($sim['Estado'] == '0'): ?>

                        <?php if ($is_criador || $is_mesma_equipa): ?>
                            <a href="../php/iniciar_simulacao.php?id=<?php echo $sim['IDSimulacao']; ?>" class="btn-submit" style="background-color: #28a745; text-decoration: none;">Iniciar Simulação</a>
                        <?php endif; ?>

                        <?php if ($is_criador): ?>
                            <a href="configurar_simulacao.php?id=<?php echo $sim['IDSimulacao']; ?>" class="edit-icon" title="Editar Parâmetros">
                                <i class="fas fa-pencil-alt" style="color: #444; font-size: 1.2rem;"></i>
                            </a>
                        <?php else: ?>
                            <a href="detalhes_simulacao.php?id=<?php echo $sim['IDSimulacao']; ?>" class="btn-submit">Ver detalhes</a>
                        <?php endif; ?>

                    <?php else: ?>
                        <a href="detalhes_simulacao.php?id=<?php echo $sim['IDSimulacao']; ?>" class="btn-submit" style="background-color: var(--tech-blue);">Ver detalhes</a>
                    <?php endif; ?>
                </div>
            </div>
        <?php endforeach; ?>
    <?php endif; ?>
    <?php if (isset($_GET['erro'])): ?>
        <script>
            // O PHP escreve a mensagem de erro diretamente dentro do alert do JavaScript
            alert("<?php echo htmlspecialchars($_GET['erro']); ?>");
            
            // Esta linha limpa o '?erro=...' do link lá em cima, para que se o utilizador 
            // fizer F5 (refresh) à página, o pop-up não volte a aparecer do nada!
            window.history.replaceState(null, null, window.location.pathname);
        </script>
    <?php endif; ?>
</div>

<?php include('includes/footer.php'); ?>
