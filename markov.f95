module markov 
  use constants
  use plotroutines
  implicit none
  private
  public :: run_sim, gen_config

contains
  subroutine run_sim(S,BE,BJ,h,t,r,m,runtime,c_ss,c_ss_fit)
    integer, intent(inout) :: S(:,:)
    real(dp), intent(inout) :: BE(:), BJ, h
    real(dp), intent(out) :: c_ss(:), r(:), c_ss_fit(:)
    integer, intent(out) :: t(:), m(:), runtime
    real(dp) :: p, offset, err_alpha, alpha
    real(dp), allocatable :: g(:,:)
    integer :: i, j, start_time, m_tmp, end_time
    
    allocate(g(n_meas,r_max))
    ! initialize needed variables
    j = 0
    h = 0._dp ! overwrite user setting, just in case 
    t = (/(i,i=0,n_meas-1)/)
    r = real((/(i,i=1,r_max)/),dp)
    p = 1 - exp(-2._dp*BJ)

    call system_clock(start_time)
    do i=1,steps
      call gen_config(S,m_tmp,p)

      if (mod(i,meas_step) == 0) then
        j = j+1
        m(j) = m_tmp
        call s_corr(g(j,:),S)
        call calc_energy(BE(j),S,BJ,h)
      endif
      if (mod(i,N/10) == 0)  call write_lattice(S) ! write lattice to pipe
    enddo    
    call system_clock(end_time)
    runtime = (end_time - start_time)/1000
    
    ! calculate correlation function 
    c_ss = sum(g(meas_start:n_meas,:),1)/(n_meas-meas_start) 
    call lin_fit(alpha,err_alpha,offset,-log(c_ss),log(r))
    c_ss_fit = exp(-offset)*r**(-alpha)

    print *, 'slope =', alpha
    deallocate(g)
  end subroutine

  subroutine gen_config(S,m,p)
    integer, intent(inout) :: S(:,:)
    integer, intent(out) :: m
    real(dp), intent(in) :: p
    integer, allocatable :: C(:,:)
    integer :: i, j, S_init, s_cl, x(2), nn(4,2)
    real(dp) :: r
    
    allocate(C(N,2))

    ! initialize variables 
    i = 1 ! labels spin in cluster
    s_cl = 1 ! number of spins in cluster
    C = 0 ! init array that holds indices of all spins in cluster

    call random_spin(x) ! start cluster by choosing 1 spin

    S_init = S(x(1),x(2)) ! save state of chosen spin
    C(1,:) = x ! add chosen spin to cluster     
    S(x(1),x(2)) = -S_init ! flip initial spin
    
    do while (i<=s_cl)
      x = C(i,:) ! pick a spin x in the cluster
      nn = nn_idx(x) ! get nearest neighbors of spin x
      
      ! iterate over neighbors of x
      do j = 1,4 
        if (S(nn(j,1),nn(j,2)) == S_init) then 
          ! dit stuk kan in een try add subroutine
          call random_number(r)

          if (r<p) then ! add spin to cluster with probability p
            s_cl = s_cl+1
            C(s_cl,:) = nn(j,:) 
            
            S(nn(j,1),nn(j,2)) = -S_init ! flip spin
          endif
        endif
      enddo
      i = i+1 ! move to next spin in cluster
    enddo 

    m = sum(S) ! calculate instantaneous magnetization
    deallocate(C)
  end subroutine

  subroutine random_spin(x)
    ! returns index of randomly picked spin
    integer, intent(out) :: x(:)
    real(dp) :: u(2)

    call random_number(u)
    u = L*u + 0.5_dp
    x = nint(u) ! index of spin to flip
  end subroutine

  pure subroutine calc_energy(BE,S,BJ,h)
    real(dp), intent(out) :: BE
    integer, intent(in) :: S(:,:)
    real(dp), intent(in) :: h, BJ
    integer :: i, j, k, nn(4,2)

    if (size(S,1) < 2) return !check
    
    BE = 0._dp ! initialze energy 
    
    do i = 1,L
      do j = 1,L
        nn = nn_idx([i,j]) ! get nearest neighbors of spin i,j
        
        do k = 1,4
          BE = BE - BJ*S(i,j)*S(nn(k,1),nn(k,2))
        enddo
      enddo
    enddo

    BE = 0.5_dp*BE ! account for double counting of pairs
    BE = BE - h*sum(S) ! add external field
  end subroutine
  
  pure function nn_idx(x)
    ! returns indices of nearest neighbors of x_ij, accounting for PBC
    integer, intent(in) :: x(2)
    integer :: nn_idx(4,2)

    nn_idx(1,:) = merge(x + [1,0], 1, x(1) /= L)
    nn_idx(2,:) = merge(x + [0,1], 1, x(2) /= L) 
    nn_idx(3,:) = merge(x - [1,0], L, x(1) /= 1) 
    nn_idx(4,:) = merge(x - [0,1], L, x(2) /= 1) 
  end function

  pure subroutine s_corr(g,S)
    real(dp), intent(out) :: g(:)
    integer, intent(in) :: S(:,:)
    real(dp) :: g_tmp(n_corr,r_max)
    integer :: i, r_0, r_1
     
    r_0 = (L-n_corr)/2
    r_1 = r_0 + 1

    do i=1,n_corr
      g_tmp(i,:) = S(i+r_0,i+r_0)*&
        (S(i+r_0,i+r_1:i+r_0+r_max) + S(i+r_1:i+r_0+r_max,i+r_0))/2._dp
    enddo

    g = sum(g_tmp,1)/n_corr 
  end subroutine

  pure subroutine lin_fit(slope,err_slope,offset,y,x)
    real(dp), intent(out) :: slope, err_slope, offset
    real(dp), intent(in) :: y(:), x(:)
    real(dp) :: mu_x, mu_y, ss_yy, ss_xx, ss_yx, s
    ! linear regression
    ! see also: http://mathworld.wolfram.com/LeastSquaresFitting.html

    mu_x = sum(x)/size(x)
    mu_y = sum(y)/size(y)

    ss_yy = sum((y - mu_y)**2)
    ss_xx = sum((x - mu_x)**2)
    ss_yx = sum((x - mu_x)*(y - mu_y))
    
    slope = ss_yx/ss_xx
    offset = mu_y - slope*mu_x
    s = sqrt((ss_yy - slope*ss_yx)/(size(x)-2))

    err_slope = s/(sqrt(ss_xx)*6._dp) ! error in slope calc
  end subroutine
end module
