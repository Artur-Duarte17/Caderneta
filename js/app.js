// ===== APP.JS - Vendas a Prazo =====

// Configuração das páginas
const pageConfig = {
    'index.html': { title: 'Visão Geral', breadcrumb: 'Visão Geral' },
    'clientes.html': { title: 'Clientes', breadcrumb: 'Clientes' },
    'vendas.html': { title: 'Vendas', breadcrumb: 'Vendas' },
    'relatorios.html': { title: 'Relatórios', breadcrumb: 'Relatórios' },
    'notificacoes.html': { title: 'Notificações', breadcrumb: 'Notificações' }
};

// Função para carregar componentes
async function loadComponent(elementId, componentPath) {
    try {
        const response = await fetch(componentPath);
        const html = await response.text();
        document.getElementById(elementId).innerHTML = html;
    } catch (error) {
        console.error(`Erro ao carregar componente ${componentPath}:`, error);
    }
}

// Função para configurar página atual
function setupCurrentPage() {
    const fullPath = window.location.pathname;
    const currentPage = fullPath.split('/').pop() || 'index.html';
    const config = pageConfig[currentPage];
    
    if (config) {
        // Atualizar título da página
        const pageTitle = document.getElementById('pageTitle');
        if (pageTitle) {
            pageTitle.textContent = config.title;
        }
        
        // Atualizar breadcrumb
        const currentPageBreadcrumb = document.getElementById('currentPage');
        if (currentPageBreadcrumb) {
            currentPageBreadcrumb.textContent = config.breadcrumb;
        }
        
        // Marcar item ativo na sidebar
        setActiveSidebarItem(currentPage);
    }
}

// Função para marcar item ativo na sidebar
function setActiveSidebarItem(currentPage) {
    // Remove active de todos os itens
    document.querySelectorAll('.sidebar-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Adiciona active ao item atual
    const pageKey = currentPage.replace('.html', '');
    const activeItem = document.querySelector(`[data-page="${pageKey}"]`);
    if (activeItem) {
        activeItem.classList.add('active');
    }
}

// Função para configurar sidebar mobile
function setupMobileSidebar() {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.getElementById('sidebar');
    const sidebarOverlay = document.getElementById('sidebarOverlay');
    
    if (sidebarToggle && sidebar && sidebarOverlay) {
        sidebarToggle.addEventListener('click', () => {
            sidebar.classList.toggle('show');
            sidebarOverlay.classList.toggle('show');
        });
        
        sidebarOverlay.addEventListener('click', () => {
            sidebar.classList.remove('show');
            sidebarOverlay.classList.remove('show');
        });
        
        // Fechar sidebar ao clicar em um link (mobile)
        sidebar.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                if (window.innerWidth < 768) {
                    sidebar.classList.remove('show');
                    sidebarOverlay.classList.remove('show');
                }
            });
        });
    }
}

// Função para configurar tooltips do Bootstrap
function setupBootstrapComponents() {
    // Tooltips
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

// Função para validação de formulários
function setupFormValidation() {
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            
            let isValid = true;
            const requiredInputs = this.querySelectorAll('[required]');
            
            requiredInputs.forEach(input => {
                if (!input.value.trim()) {
                    input.classList.add('is-invalid');
                    isValid = false;
                } else {
                    input.classList.remove('is-invalid');
                }
            });
            
            if (isValid) {
                showToast('Operação realizada com sucesso!', 'success');
                
                // Fechar modal se existir
                const modal = this.closest('.modal');
                if (modal) {
                    const bsModal = bootstrap.Modal.getInstance(modal);
                    if (bsModal) bsModal.hide();
                }
            }
        });
    });
}

// Função para mostrar toast
function showToast(message, type = 'success') {
    const toastContainer = document.getElementById('toastContainer') || createToastContainer();
    
    const toastEl = document.createElement('div');
    toastEl.className = `toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'}`;
    toastEl.setAttribute('role', 'alert');
    toastEl.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">${message}</div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
        </div>
    `;
    
    toastContainer.appendChild(toastEl);
    
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
    
    // Remove o elemento após o toast ser ocultado
    toastEl.addEventListener('hidden.bs.toast', () => {
        toastEl.remove();
    });
}

// Função para criar container de toast se não existir
function createToastContainer() {
    const container = document.createElement('div');
    container.id = 'toastContainer';
    container.className = 'toast-container position-fixed bottom-0 end-0 p-3';
    container.style.zIndex = '1055';
    document.body.appendChild(container);
    return container;
}

// Inicialização quando o DOM estiver carregado
document.addEventListener('DOMContentLoaded', async function() {
    // Determinar caminho base dos componentes
    const isInSubdir = window.location.pathname.includes('/Paginas/');
    const basePath = isInSubdir ? '../' : '';
    
    // Carregar componentes
    const sidebarFile = isInSubdir ? 'sidebar-paginas.html' : 'sidebar.html';
    await Promise.all([
        loadComponent('sidebarContainer', basePath + 'components/' + sidebarFile),
        loadComponent('topbarContainer', basePath + 'components/topbar.html')
    ]);
    
    // Configurar página atual
    setupCurrentPage();
    
    // Configurar sidebar mobile
    setupMobileSidebar();
    
    // Configurar componentes do Bootstrap
    setupBootstrapComponents();
    
    // Configurar validação de formulários
    setupFormValidation();
});

// Exportar funções para uso global
window.showToast = showToast;