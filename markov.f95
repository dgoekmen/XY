module markov 
  use constants
  use main_routines
  use plotroutines
  implicit none
  private
  public :: run_sim

contains
  subroutine run_sim(S,BE,K,t,m,runtime)
    real(dp), intent(inout) :: S(:,:,:), BE(:), K, m(:)
    integer, intent(inout) :: t(:)
    integer, intent(out) :: runtime

    integer :: i, j, start_time, end_time
    real(dp) :: m_tmp
    
    ! initialize needed variables
    j = 0
    t = (/(i,i=0,n_meas-1)/)

    call system_clock(start_time)
    do i=1,steps
      call gen_config(S,m_tmp,K)

      if (mod(i,meas_step) == 0) then
        j = j+1
        m(j) = m_tmp
        call calc_energy(BE(j),S,K)
      endif

      if (mod(i,plot_interval) == 0) call write_lattice(S) ! write lattice to pipe
    enddo    
    call system_clock(end_time)
    runtime = (end_time - start_time)/1000
  end subroutine

  subroutine gen_config(S,m,K)
    real(dp), intent(inout) :: S(:,:,:)
    real(dp), intent(in) :: K
    real(dp), intent(out) :: m

    integer, allocatable :: C(:,:)
    logical, allocatable :: C_added(:,:)
    integer :: i, j, s_cl, x(2), nn(4,2)
    real(dp) :: a, u(2)
    
    allocate(C(N,2),C_added(N,N))
    ! initialize variables 
    i = 1 ! labels spin in cluster
    s_cl = 1 ! number of spins in cluster
    C_added = .false. ! tells us if spin was already considered for cluster
    C = 0 ! init array that holds indices of all spins in cluster

    call random_idx(x) ! start cluster by choosing 1 spin
    C(1,:) = x
    C_added(x(1),x(2)) = .true. ! add chosen spin to cluster     
    call random_dir(u) 
    
    ! flip initial spin
    a = dot_product(S(x(1),x(2),:),u) 
    S(x(1),x(2),:) = S(x(1),x(2),:) - 2._dp*a*u  
    
    do while (i<=s_cl)
      x = C(i,:) ! pick a spin x in the cluster
      nn = nn_idx(x) ! get nearest neighbors of spin x
      
      do j = 1,4 ! iterate over neighbors of x
        call try_add(S,C,C_added,s_cl,a,u,nn(j,:),K)
      enddo
      i = i+1 ! move to next spin in cluster
    enddo

    m = sum(S) ! calculate instantaneous magnetization
    deallocate(C,C_added)
  end subroutine

  subroutine try_add(S,C,C_added,s_cl,a,u,s_idx,K)
    real(dp), intent(inout) :: S(:,:,:)
    integer, intent(inout) :: s_cl, C(:,:)
    logical, intent(inout) :: C_added(:,:)
    integer, intent(in) :: s_idx(:)
    real(dp), intent(in) :: a, K, u(:)

    real(dp) :: r, p, b
    
    if (C_added(s_idx(1),s_idx(2)) .eqv. .false.) then
      b = a*dot_product(S(s_idx(1),s_idx(2),:),u)
      p = 1 - exp(-2*K*b) ! check of dit echt klopt 
      call random_number(r)

      if (r<p) then ! add spin to cluster with probability p
        s_cl = s_cl+1
        C_added(s_idx(1),s_idx(2)) = .true. 

        C(s_cl,:) = s_idx 
        S(s_idx(1),s_idx(2),:) = S(s_idx(1),s_idx(2),:) - &
          2._dp*dot_product(S(s_idx(1),s_idx(2),:),u)*u  
      endif
    endif
  end subroutine

  pure subroutine calc_energy(BE,S,K)
    real(dp), intent(out) :: BE
    real(dp), intent(in) :: S(:,:,:), K

!    integer :: i, j, k, nn(4,2)
    ! nog aanpassen voor xy model
    BE = 0._dp
!
!    if (size(S,1) < 2) return !check
!    
!    BE = 0._dp ! initialze energy 
!
!    do i = 1,L
!      do j = 1,L
!        nn = nn_idx([i,j]) ! get nearest neighbors of spin i,j
!        do k = 1,4
!          BE = BE - K*S(i,j)*S(nn(k,1),nn(k,2))
!        enddo
!      enddo
!    enddo

!    BE = 0.5_dp*BE ! account for double counting of pairs
!    BE = BE - h*sum(S) ! add external field
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
    r = [cos(u), sin(u)]
  end subroutine
end module