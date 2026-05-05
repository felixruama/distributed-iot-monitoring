<?php include('includes/header.php'); ?>

<div class="container">
    <div style="text-align: center; margin-bottom: 40px;">
        <h1 style="font-size: 2.2rem;">O meu Perfil</h1>
        <p style="color: #888;">Gere as tuas informações de conta e contacto</p>
    </div>

    <div class="card profile-card">
        <form action="../php/processar_perfil.php" method="POST">

            <h2 style="font-size: 1.4rem; border-bottom: none; margin-bottom: 35px; color: #444;">
                <i class="fas fa-id-card" style="margin-right: 10px; color: var(--tech-blue);"></i>
                Dados do Utilizador
            </h2>

            <div class="profile-grid">
                <!-- Nome (Ocupa a largura toda) -->
                <div class="form-group-alt full-width">
                    <label>Nome Completo</label>
                    <div class="input-pill">
                        <input type="text" name="nome" value="Utilizador de Teste" required>
                        <i class="fas fa-user"></i>
                    </div>
                </div>

                <!-- Telemóvel -->
                <div class="form-group-alt">
                    <label>Telemóvel</label>
                    <div class="input-pill">
                        <input type="tel" name="telemovel" value="912345678">
                        <i class="fas fa-phone"></i>
                    </div>
                </div>

                <!-- Email -->
                <div class="form-group-alt">
                    <label>E-mail</label>
                    <div class="input-pill">
                        <input type="email" name="email" value="exemplo@email.com" required>
                        <i class="fas fa-envelope"></i>
                    </div>
                </div>

                <!-- Data de Nascimento -->
                <div class="form-group-alt">
                    <label>Data de Nascimento</label>
                    <div class="input-pill">
                        <input type="date" name="data_nascimento" value="1995-10-20">
                        <i class="fas fa-calendar-alt"></i>
                    </div>
                </div>

                <!-- Podes adicionar um campo extra aqui (ex: Cargo ou Data de Registo) se quiseres preencher o buraco -->
                <div class="form-group-alt">
                    <label>ID de Utilizador (Apenas Leitura)</label>
                    <div class="input-pill" style="background-color: #f9f9f9; opacity: 0.7;">
                        <input type="text" value="#<?php echo $_SESSION['user_id'] ?? '001'; ?>" readonly>
                        <i class="fas fa-lock"></i>
                    </div>
                </div>
            </div>

            <!-- Botões à direita para manter o padrão da configuração -->
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