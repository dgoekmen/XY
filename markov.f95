module markov 
  use constants
  use main_routines
  use plotroutines
  implicit none
  private
  public :: run_sim

contains
  subroutine run_sim(S,BE,BK,t,h_mod,runtime)
    real(dp), intent(inout) :: S(:,:,:), BE(:), BK
    integer, intent(inout)  :: t(:)
    integer, intent(out)    :: runtime

    real(dp), allocatable :: G(:)
    real(dp)  :: h_mod
    integer   :: i, j, start_time, end_time
    
    allocate(G(n_meas))
    ! initialize needed variables
    j = 0
    t = (/(i,i=0,n_meas-1)/)

    call system_clock(start_time)
    do i=1,steps
      call gen_config(S,BK)

      if (mod(i,meas_step) == 0) then
        j = j+1
        call calc_energy(BE(j),S,BK)
        call helicity_mod(G(j),S,BK)
      endif

      if (mod(i,plot_interval) == 0) call write_lattice(S) ! lattice to pipe
    enddo    
    call system_clock(end_time)
    runtime = (end_time - start_time)/1000

    h_mod = sum(G)/n_meas
    deallocate(G)
  end subroutine

  subroutine gen_config(S,BK)
    real(dp), intent(inout) :: S(:,:,:)
    real(dp), intent(in)    :: BK

    integer, allocatable :: C(:,:)
    logical, allocatable :: C_added(:,:)
    integer   :: i, j, s_cl, x(2), nn(4,2)
    real(dp)  :: S_dot_u, u(2)
    
    allocate(C(N,2),C_added(N,N))
    ! initialize variables 
    C = 0 ! cluster
    C_added = .false. ! tags for spins in the cluster
    i = 1 ! labels for spin in cluster
    s_cl = 1 ! number of spins in cluster

    call random_idx(x) ! start cluster by choosing 1 spin
    call random_dir(u) ! get random unit vector

    C(1,:) = x ! add chosen spin to cluster  
    C_added(x(1),x(2)) = .true. ! tag spin     

    S(:,x(1),x(2)) = Flip(S(:,x(1),x(2)),u) ! flip initial spin
    S_dot_u = dot_product(S(:,x(1),x(2)),u) 
    
    do while (i<=s_cl)
      x = C(i,:) ! pick a spin x in the cluster
      nn = nn_idx(x) ! get nearest neighbors of spin x
      
      do j = 1,4 ! iterate over nearest neighbors of x
        call try_add(S,C,C_added,s_cl,S_dot_u,u,nn(j,:),BK)
      enddo
      i = i+1 ! move to next spin in cluster
    enddo
    deallocate(C,C_added)
  end subroutine

  subroutine try_add(S,C,C_added,s_cl,S_dot_u,u,s_idx,BK)
    real(dp), intent(inout) :: S(:,:,:)
    integer, intent(inout)  :: s_cl, C(:,:)
    logical, intent(inout)  :: C_added(:,:)
    integer, intent(in)     :: s_idx(:)
    real(dp), intent(in)    :: S_dot_u, BK, u(:)

    integer   :: i, j 
    real(dp)  :: r, p, Sy_dot_u

    i = s_idx(1)
    j = s_idx(2)
    
    if (C_added(i,j) .eqv. .false.) then ! check if spin already in C
      call random_number(r)
      Sy_dot_u = dot_product(S(:,i,j),u)
      p = 1 - exp(2*BK*S_dot_u*Sy_dot_u)  

      if (r<p) then ! add spin to cluster with probability p
        s_cl = s_cl+1 ! increase nr of spins in cluster
        C(s_cl,:) = s_idx ! add to cluster
        C_added(i,j) = .true. ! tag spin as added to C 

        S(:,i,j) = Flip(S(:,i,j),u) ! flip spin 
      endif
    endif
  end subroutine

  pure function nn_idx(x)
    ! returns indices of nearest neighbors of x_ij, accounting for PBC
    integer, intent(in) :: x(2)
    integer :: nn_idx(4,2)

    nn_idx(1,:) = merge(x + [1,0], [1,x(2)], x(1) /= L)
    nn_idx(2,:) = merge(x + [0,1], [x(1),1], x(2) /= L) 
    nn_idx(3,:) = merge(x - [1,0], [L,x(2)], x(1) /= 1) 
    nn_idx(4,:) = merge(x - [0,1], [x(1),L], x(2) /= 1) 
  end function

  pure function Flip(S,u)
    ! flips spin wrt unit vector u
    real(dp), intent(in) :: S(:), u(:)
    real(dp) :: Flip(2)
    
    Flip = S - 2._dp*dot_product(S,u)*u  
    Flip = Flip/sqrt(sum(Flip**2)) ! ensure normalization of spins   
  end function
  
  subroutine random_idx(x)
    ! returns index of randomly picked spin
    integer, intent(out) :: x(:)
    real(dp) :: u(2)

    call random_number(u)
    u = L*u + 0.5_dp
    x = nint(u) ! index of spin to flip
  end subroutine

  subroutine random_dir(r)
    ! returns random unit vector 
    real(dp), intent(out) :: r(:)
    real(dp) :: u

    call random_number(u)
    u = 2._dp*pi*u
    r = [cos(u),sin(u)]
  end subroutine
  
  pure function angle(S)
    real(dp), intent(in) :: S(:)
    real(dp)             :: angle
    ! convert spin vector to angle wrt x-axis
    
    angle = atan2(S(2),S(1)) 
  end function

  pure subroutine calc_energy(BE,S,BK)
    ! calculate energy of the system
    real(dp), intent(out) :: BE
    real(dp), intent(in)  :: S(:,:,:), BK
    integer               :: i, j, k, nn(4,2)
    
    BE = 0._dp ! init energy 

    do i = 1,L
      do j = 1,L
        nn = nn_idx([i,j]) ! get nearest neighbors of spin i,j
        do k = 1,4
          BE = BE - BK*dot_product(S(:,i,j),S(:,nn(k,1),nn(k,2)))
        enddo
      enddo
    enddo

    BE = 0.5_dp*BE ! correct for double counting of pairs
  end subroutine

  pure subroutine helicity_mod(G,S,BK)
    real(dp), intent(out) :: G
    real(dp), intent(in)  :: S(:,:,:), BK
    
    real(dp), allocatable :: dthetax(:,:), dthetay(:,:)
    integer               :: i, j, k, nn(4,2)

    allocate(dthetax(L,L),dthetay(L,L))
    G = 0._dp

    do i=1,L
      do j=1,L
        nn=nn_idx([i,j])
        dthetax(i,j) = angle(S(:,i,j)) - angle(S(:,modulo(i,L)+1,j))
        dthetay(i,j) = angle(S(:,i,j)) - angle(S(:,i,modulo(j,L)+1))
        do k=1,4
          G = G + dot_product(S(:,i,j),S(:,nn(k,1),nn(k,2)))
        enddo
      enddo
    enddo

    G = 0.5_dp*G ! double counting correction
    G = G - BK*(sum(sin(dthetax))**2 + sum(sin(dthetay))**2)
    G = G/(2._dp*N)
    deallocate(dthetax,dthetay)
  end subroutine
end module
