module io
  use constants
  implicit none
  private
  public :: user_in, results_out
contains

  subroutine user_in(K)
    real(dp), intent(out) :: K
  
    write(*,'(/,A,/)') '************ Input *************' 
    write(*,'(A)',advance='no') "K = " 
    read(*,*) K
    write(*,'(A)') "Running simulation..."
  end subroutine

  subroutine results_out(K,BE,runtime) 
    real(dp), intent(in) :: K, BE
    integer, intent(in) :: runtime

    open(12,access = 'sequential',file = 'output.txt')
      write(12,'(/,A,/)') '*********** Summary ***********' 
      write(12,*) "K :", K
    
      write(12,'(/,A,/)') '*********** Output ************' 
      write(12,'(A,I6,A)') "Runtime : ", runtime, " s"
      write(12,*) "Final Energy", BE
      write(12,'(/,A,/)') '*******************************' 
    close(12)
    
    call system('cat output.txt')
  end subroutine
end module
