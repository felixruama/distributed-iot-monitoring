<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8">
    <title>MAZERUN 2026 - Login</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="css/style.css">
</head>
<body class="login-page">

    <div class="hero-banner">
        <h1>MAZERUN 2026</h1>
    </div>

    <div class="container" style="display: flex; justify-content: center; align-items: center; flex: 1;">
        <div class="card login-card" style="max-width: 450px; padding: 40px; text-align: center;">

            <h2 style="border: none; margin-bottom: 30px; font-size: 1.8rem; color: var(--tech-blue);">Login</h2>

            <form action="../php/validar_login.php" method="POST">

                <!-- Campo Email -->
                <div class="form-group-alt" style="margin-bottom: 20px; text-align: left;">
                    <label>E-mail</label>
                    <div class="input-pill">
                        <input type="email" name="email" placeholder="nome@exemplo.com" required>
                        <i class="fas fa-envelope"></i>
                    </div>
                </div>

                <!-- Campo Password -->
                <div class="form-group-alt" style="margin-bottom: 30px; text-align: left;">
                    <label>Password</label>
                    <div class="input-pill">
                        <input type="password" name="password" placeholder="••••••••" required>
                        <i class="fas fa-lock"></i>
                    </div>
                </div>

              <!-- Botão centralizado e mais pequeno -->
           <div style="display: flex; justify-content: center; margin-top: 30px;">
                <button type="submit" class="btn-submit" style="padding: 10px 40px; font-size: 0.95rem;">
                         Entrar
                </button>
           </div>

            </form>

            <p style="margin-top: 25px; font-size: 0.85rem; color: #888;">
                Sistema de Gestão de Labirintos e Simulações
            </p>
        </div>
    </div>

    <footer>
        2026 PISID - MazeRun Project.
    </footer>

</body>
</html>